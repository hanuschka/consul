require "rails_helper"

describe "Separate reporter answer for Anliegen", type: :request do
  include ApiClientHelper

  let(:officer) { create(:deficiency_report_officer) }
  let(:report) { create(:deficiency_report, admin_accepted: true, responsible: officer) }
  let(:box_title) { I18n.t("custom.deficiency_reports.show.official_answer.title") }

  before do
    create(:deficiency_report_status)
    set_setting("process.deficiency_reports", true)
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  def save_answers(**answers)
    patch update_official_answer_adm_deficiency_reports_deficiency_report_path(report),
          params: { deficiency_report: answers },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  context "with the setting off" do
    before { login_as(officer.user) }

    it "shows one answer field, publishes the answer and e-mails it to the reporter" do
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to include('name="deficiency_report[official_answer]"')
      expect(response.body).not_to include('name="deficiency_report[reporter_answer]"')

      expect { save_answers(official_answer: "Die Laterne wird morgen repariert.") }
        .to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)

      logout
      get deficiency_report_path(report)

      expect(response.body).to include(box_title, "Die Laterne wird morgen repariert.")
    end
  end

  context "with the setting on" do
    before do
      set_setting("deficiency_reports.separate_reporter_answer", true)
      login_as(officer.user)
    end

    it "shows both answer fields" do
      get adm_deficiency_reports_deficiency_report_path(report)

      expect(response.body).to include('name="deficiency_report[reporter_answer]"',
                                       'name="deficiency_report[official_answer]"')
    end

    it "e-mails the reporter answer once when it is saved" do
      expect { save_answers(reporter_answer: "Vielen Dank, wir kümmern uns.", official_answer: "") }
        .to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer).once

      mail = DeficiencyReportMailer.notify_author_about_official_answer(report.reload)
      expect(mail.body.encoded).to include("Vielen Dank, wir kümmern uns.")
    end

    it "sends the reporter nothing when only the public answer is saved" do
      expect { save_answers(official_answer: "Wird repariert.") }
        .not_to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)
    end

    it "notifies watchers when only the public answer changes" do
      create(:deficiency_report_watch, deficiency_report: report)

      expect { save_answers(official_answer: "Wird repariert.") }
        .to have_enqueued_mail(DeficiencyReportMailer, :notify_watcher_about_change)
    end

    it "keeps the reporter answer off the public page and out of the search" do
      report.update!(reporter_answer: "Persönliche Rückmeldung zu Pflastersteinen")

      logout
      get deficiency_report_path(report)

      expect(response.body).not_to include(box_title)
      expect(response.body).not_to include("Persönliche Rückmeldung")
      expect(DeficiencyReport.search("Pflastersteinen")).not_to include(report)
    end

    it "shows an answer given before the setting was switched on as the public answer" do
      set_setting("deficiency_reports.separate_reporter_answer", false)
      report.update!(official_answer: "Bereits erledigt.")
      set_setting("deficiency_reports.separate_reporter_answer", true)

      logout
      get deficiency_report_path(report)

      expect(response.body).to include(box_title, "Bereits erledigt.")
    end

    it "exports both answers as separate CSV columns" do
      report.update!(official_answer: "Öffentlich", reporter_answer: "Persönlich")

      rows = CSV.parse(CsvServices::DeficiencyReportsExporter.new([report]).call, col_sep: ";", headers: true)

      expect(rows.first["Officielle Antwort"]).to eq "Öffentlich"
      expect(rows.first["Antwort an die meldende Person"]).to eq "Persönlich"
    end
  end

  describe "when a report counts as answered" do
    let(:author) { report.author }

    it "no longer lets the author delete a report that has only a reporter answer" do
      report.update!(reporter_answer: "Persönliche Rückmeldung")

      expect(Ability.new(author).can?(:destroy, report)).to be false
    end

    it "lets the author delete an unanswered report" do
      expect(Ability.new(author).can?(:destroy, report)).to be true
    end
  end

  describe "creating a report from the public form" do
    it "ignores a submitted reporter answer" do
      login_as(create(:user))
      category = create(:deficiency_report_category)

      expect do
        post deficiency_reports_path, params: {
          deficiency_report: {
            deficiency_report_category_id: category.id,
            resource_terms: "1",
            translations_attributes: {
              "0" => { locale: "en", title: "Kaputte Bank", description: "Die Bank im Park ist kaputt.",
                       reporter_answer: "Gefälschte Antwort" }
            },
            map_location_attributes: { latitude: 50.7956, longitude: 7.2044, zoom: 12, rendering_library: "leaflet" }
          }
        }
      end.to change(DeficiencyReport, :count).by(1)

      expect(DeficiencyReport.last.reporter_answer).to be_nil
    end
  end

  describe "REST API" do
    let(:headers) { { "Authorization" => "Bearer #{client.access_token}" } }

    before { report.update!(official_answer: "Öffentlich", reporter_answer: "Persönlich") }

    context "with an admin client" do
      let(:client) { create_api_client(access_level: :admin) }

      it "returns both answers" do
        get "/api/deficiency_reports/#{report.id}", headers: headers

        data = response.parsed_body.dig("data", "deficiency_report")
        expect(data).to include("official_answer" => "Öffentlich", "reporter_answer" => "Persönlich")
      end

      it "writes the reporter answer" do
        patch "/api/deficiency_reports/#{report.id}", headers: headers,
              params: { deficiency_report: { reporter_answer: "Neu" } }

        expect(report.reload.reporter_answer).to eq "Neu"
      end
    end

    context "with a public data client" do
      let(:client) { create_api_client(access_level: :public_data) }

      it "returns only the public answer" do
        get "/api/deficiency_reports/#{report.id}", headers: headers

        data = response.parsed_body.dig("data", "deficiency_report")
        expect(data["official_answer"]).to eq "Öffentlich"
        expect(data).not_to have_key("reporter_answer")
      end
    end
  end
end
