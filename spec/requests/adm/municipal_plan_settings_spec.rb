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
  end
end
