require "rails_helper"

describe "Anliegen notifications from /adm", type: :request do
  let(:officer) { create(:deficiency_report_officer) }

  before do
    create(:deficiency_report_status)
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  describe "saving the official answer" do
    let(:report) { create(:deficiency_report) }

    def save_answer(answer)
      patch update_official_answer_adm_deficiency_reports_deficiency_report_path(report),
            params: { deficiency_report: { official_answer: answer }},
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    before do
      report.update!(responsible: officer)
      login_as(officer.user)
    end

    it "sends the reporter an e-mail when an answer is added" do
      expect { save_answer("Die Laterne wird morgen repariert.") }
        .to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)
    end

    it "sends the reporter an e-mail when the answer is changed" do
      report.update!(official_answer: "Wird geprüft.")

      expect { save_answer("Die Laterne wird morgen repariert.") }
        .to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)
    end

    it "sends nothing when the answer is saved unchanged" do
      report.update!(official_answer: "Wird geprüft.")

      expect { save_answer("Wird geprüft.") }
        .not_to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)
    end

    it "sends nothing and shows no error when the reporter has no e-mail address" do
      report.author.update_column(:email, "")

      expect { save_answer("Die Laterne wird morgen repariert.") }
        .not_to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)
      expect(response).to have_http_status(:ok)
      expect(report.reload.official_answer).to eq "Die Laterne wird morgen repariert."
    end

    it "sends nothing for a report staff recorded without a reporter e-mail" do
      report.update_column(:recorded_by_id, report.author_id)

      expect { save_answer("Die Laterne wird morgen repariert.") }
        .not_to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_official_answer)
    end
  end

  describe "recording a report in the dashboard" do
    let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
    let(:category) { create(:deficiency_report_category, default_responsible: officer) }
    let(:map_location_attributes) do
      { latitude: 50.7956, longitude: 7.2044, zoom: 12, rendering_library: "leaflet" }
    end

    def record_in_backend(**on_behalf_of_attributes)
      post adm_deficiency_reports_deficiency_reports_path, params: {
        deficiency_report: {
          title: "Broken street lamp",
          description: "A resident called about a lamp that stays dark.",
          deficiency_report_category_id: category.id,
          map_location_attributes: map_location_attributes
        }.merge(on_behalf_of_attributes)
      }
    end

    before { login_as(manager) }

    it "notifies the responsible caseworker like a citizen's report" do
      expect { record_in_backend }.to have_enqueued_mail(DeficiencyReportMailer, :notify_officer)

      expect(DeficiencyReport.last.responsible).to eq officer
    end

    it "confirms the report to the reporting person when an e-mail address was entered" do
      expect { record_in_backend(on_behalf_of: "Erika Mustermann", on_behalf_of_email: "erika@consul.test") }
        .to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_submission)
    end

    it "sends no confirmation when no reporter e-mail was entered" do
      expect { record_in_backend }
        .not_to have_enqueued_mail(DeficiencyReportMailer, :notify_author_about_submission)
    end
  end
end
