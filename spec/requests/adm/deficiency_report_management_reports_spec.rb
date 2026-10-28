require "rails_helper"

describe "Management report archive in the deficiency report administration", type: :request do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:recipient_officer) { create(:deficiency_report_officer) }
  let(:other_officer) { create(:deficiency_report_officer) }
  let(:profile) { create(:deficiency_report_report_profile, recipient_user_ids: [recipient_officer.user_id]) }
  let(:anliegen) { create(:deficiency_report, title: "Laterne defekt") }
  let(:management_report) do
    DeficiencyReport::ManagementReport.create!(
      report_profile: profile, profile_name: profile.name, building_blocks: %w[incoming_and_closed],
      period_start: 7.days.ago, period_end: Time.current, status: :completed, generated_at: Time.current,
      figures: { "incoming_and_closed" => { "incoming" => 4, "closed" => 2 } },
      sections: [{ "building_block" => "incoming_and_closed",
                   "statements" => [{ "text" => "Mehr Meldungen zur Beleuchtung.", "report_ids" => [anliegen.id] }] }]
    )
  end

  before do
    create(:deficiency_report_status)
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  context "as a deficiency report manager" do
    before { login_as(manager) }

    it "lists the reports of a profile" do
      management_report

      get adm_deficiency_reports_report_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(adm_deficiency_reports_management_report_path(management_report))
    end

    it "creates a report on demand without sending it" do
      expect { post generate_adm_deficiency_reports_report_profile_path(profile) }
        .to change(DeficiencyReport::ManagementReport, :count).by(1)
        .and have_enqueued_job(DeficiencyReports::GenerateManagementReportJob)

      created = DeficiencyReport::ManagementReport.last
      expect(created).to be_manual
      expect(created.sent_at).to be_nil
      expect(response).to redirect_to(adm_deficiency_reports_report_profile_path(profile))
    end

    it "shows the report with figures from the data and links to the reports" do
      get adm_deficiency_reports_management_report_path(management_report)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mehr Meldungen zur Beleuchtung.",
                                       adm_deficiency_reports_deficiency_report_path(anliegen.id),
                                       I18n.t("adm.deficiency_reports.management_reports.figures.incoming"))
    end

    it "shows that a failed report could not be created, without the technical error" do
      management_report.update!(status: :failed, error_message: "Faraday::TimeoutError: execution expired")

      get adm_deficiency_reports_management_report_path(management_report)

      expect(response.body).to include(I18n.t("adm.deficiency_reports.management_reports.show.failed"))
      expect(response.body).not_to include("Faraday::TimeoutError")
    end

    it "downloads the report as PDF" do
      get adm_deficiency_reports_management_report_path(management_report, format: :pdf)

      expect(response.media_type).to eq "application/pdf"
      text = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join(" ").squeeze(" ")
      expect(text).to include("Mehr Meldungen zur Beleuchtung.", "##{anliegen.id}")
    end
  end

  context "as an officer who receives the profile" do
    before { login_as(recipient_officer.user) }

    it "can open the report" do
      get adm_deficiency_reports_management_report_path(management_report)

      expect(response).to have_http_status(:ok)
    end

    it "cannot open the archive or create reports" do
      get adm_deficiency_reports_report_profile_path(profile)
      expect(response).to redirect_to(adm_deficiency_reports_root_path)

      expect { post generate_adm_deficiency_reports_report_profile_path(profile) }
        .not_to change(DeficiencyReport::ManagementReport, :count)
    end
  end

  context "as an officer who does not receive the profile" do
    before { login_as(other_officer.user) }

    it "cannot open the report" do
      get adm_deficiency_reports_management_report_path(management_report)

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
    end
  end
end
