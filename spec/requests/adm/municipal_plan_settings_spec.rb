require "rails_helper"

describe "Vorhabenliste settings in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:officer) { create(:municipal_plan_officer) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["process.municipal_plans"] = false
    Setting["municipal_plans.officers_see_all"] = false
    Setting["municipal_plans.auto_archive"] = false
  end

  it "shows the three settings to an administrator" do
    login_as(admin)

    get adm_municipal_plans_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("setting.process.municipal_plans"))
    expect(response.body).to include(I18n.t("setting.municipal_plans.officers_see_all"))
    expect(response.body).to include(I18n.t("setting.municipal_plans.auto_archive"))
  end

  it "turns an officer away" do
    login_as(officer.user)

    get adm_municipal_plans_settings_path

    expect(response).to redirect_to(adm_root_path)
  end

  describe "the dashboard and contact person tabs" do
    before do
      Setting["adm.municipal_plans.intro_text"] = ""
      Setting["adm.municipal_plans.notice_message"] = ""
      Setting["adm.municipal_plans.notice_active"] = ""
    end

    it "shows the dashboard settings to an administrator" do
      login_as(admin)

      get dashboard_adm_municipal_plans_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("setting.adm.municipal_plans.intro_text"))
    end

    it "shows the contact persons to an administrator" do
      login_as(admin)

      get contact_persons_adm_municipal_plans_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(new_adm_municipal_plans_contact_person_path)
    end

    it "turns an officer away from both tabs" do
      login_as(officer.user)

      get dashboard_adm_municipal_plans_settings_path
      expect(response).to redirect_to(adm_root_path)

      get contact_persons_adm_municipal_plans_settings_path
      expect(response).to redirect_to(adm_root_path)
    end
  end

  describe "switching a setting through the attribute endpoint" do
    def switch_on(key)
      setting = Setting.find_by!(key: key)
      patch adm_attribute_path(record_type: "setting", id: setting.id),
            params: { attribute: "value", kind: "boolean", setting: { value: "true" } }
    end

    it "works for an administrator" do
      login_as(admin)

      switch_on("municipal_plans.officers_see_all")

      expect(Setting["municipal_plans.officers_see_all"]).to be_present
    end

    it "is refused to an officer" do
      login_as(officer.user)

      switch_on("municipal_plans.officers_see_all")

      expect(Setting["municipal_plans.officers_see_all"]).to be_blank
    end
  end

  it "keeps an officer away from the contact person form" do
    login_as(officer.user)

    get new_adm_municipal_plans_contact_person_path

    expect(response).not_to have_http_status(:ok)
  end
end
