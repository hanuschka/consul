require "rails_helper"

describe "Report profiles in the deficiency report administration", type: :request do
  let(:manager) { create(:user).tap { |user| DeficiencyReportManager.create!(user: user) } }
  let(:officer) { create(:deficiency_report_officer) }

  let(:valid_params) do
    {
      deficiency_report_report_profile: {
        name: "Bürgermeister",
        building_blocks: ["", "incoming_and_closed", "top_categories"],
        category_ids: [""],
        officer_group_ids: [""],
        recipient_user_ids: ["", officer.user_id.to_s],
        recipient_emails_text: "buergermeister@example.org",
        instructions: "Straßenbeleuchtung nicht berücksichtigen",
        frequency: "weekly",
        weekday: "5",
        day_of_month: "",
        hour: "15"
      }
    }
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  context "as a deficiency report manager" do
    before { login_as(manager) }

    it "lists the profiles" do
      create(:deficiency_report_report_profile, name: "Amtsleitung Ordnungsamt")

      get adm_deficiency_reports_report_profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Amtsleitung Ordnungsamt")
    end

    it "shows the form with the people who can receive reports" do
      officer
      get new_adm_deficiency_reports_report_profile_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(officer.user.email)
    end

    it "creates a profile" do
      expect { post adm_deficiency_reports_report_profiles_path, params: valid_params }
        .to change(DeficiencyReport::ReportProfile, :count).by(1)

      profile = DeficiencyReport::ReportProfile.last
      expect(profile).to have_attributes(
        name: "Bürgermeister",
        building_blocks: ["incoming_and_closed", "top_categories"],
        recipient_user_ids: [officer.user_id],
        recipient_emails: ["buergermeister@example.org"],
        weekday: 5,
        day_of_month: nil,
        hour: 15
      )
      expect(response).to redirect_to(adm_deficiency_reports_report_profiles_path)
    end

    it "shows the form again with the error when no recipient is given" do
      valid_params[:deficiency_report_report_profile].merge!(recipient_user_ids: [""], recipient_emails_text: "")

      expect { post adm_deficiency_reports_report_profiles_path, params: valid_params }
        .not_to change(DeficiencyReport::ReportProfile, :count)

      expect(response.body).to include(
        I18n.t("activerecord.errors.models.deficiency_report/report_profile.attributes.recipient_user_ids.no_recipients")
      )
    end

    it "updates a profile to a monthly schedule" do
      profile = create(:deficiency_report_report_profile)

      patch adm_deficiency_reports_report_profile_path(profile),
            params: { deficiency_report_report_profile: { frequency: "monthly", day_of_month: "1", weekday: "5" }}

      expect(profile.reload).to have_attributes(frequency: "monthly", day_of_month: 1, weekday: nil)
    end

    it "pauses and resumes a profile" do
      profile = create(:deficiency_report_report_profile)

      patch pause_adm_deficiency_reports_report_profile_path(profile)
      expect(profile.reload).to be_paused

      patch resume_adm_deficiency_reports_report_profile_path(profile)
      expect(profile.reload).not_to be_paused
    end

    it "deletes a profile" do
      profile = create(:deficiency_report_report_profile)

      expect { delete adm_deficiency_reports_report_profile_path(profile) }
        .to change(DeficiencyReport::ReportProfile, :count).by(-1)
    end
  end

  context "as an officer who manages all reports" do
    before do
      officer.update!(manage_all: true)
      login_as(officer.user)
    end

    it "can open the profiles" do
      get adm_deficiency_reports_report_profiles_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "as an officer limited to their own reports" do
    before { login_as(officer.user) }

    it "cannot open the profiles" do
      get adm_deficiency_reports_report_profiles_path

      expect(response).to redirect_to(adm_deficiency_reports_root_path)
    end

    it "cannot create a profile" do
      expect { post adm_deficiency_reports_report_profiles_path, params: valid_params }
        .not_to change(DeficiencyReport::ReportProfile, :count)
    end
  end
end
