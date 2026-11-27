require "rails_helper"

describe "Angebote settings in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:user) { create(:user) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["process.offers"] = false
    Setting["offers.reminder_interval"] = "off"
  end

  it "shows the module switch to an administrator" do
    login_as(admin)

    get adm_offers_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("setting.process.offers"))
  end

  it "shows the reminder interval select to an administrator" do
    login_as(admin)

    get adm_offers_settings_path

    expect(response.body).to include(I18n.t("setting.offers.reminder_interval"))
    expect(response.body).to include(I18n.t("setting.offers.reminder_interval_options.quarterly"))
  end

  it "turns any other user away" do
    login_as(user)

    get adm_offers_settings_path

    expect(response).to redirect_to(adm_root_path)
  end

  it "lets an administrator switch the module on" do
    login_as(admin)
    setting = Setting.find_by!(key: "process.offers")

    patch adm_attribute_path(record_type: "setting", id: setting.id),
          params: {
            attribute: "value",
            kind: "boolean",
            field_token: Adm::AttributeEditorToken.generate(setting, "value", "boolean"),
            setting: { value: "true" }
          }

    expect(Setting["process.offers"]).to be_present
  end

  describe "as an Angebote-Administrator" do
    before { login_as(create(:offer_manager).user) }

    def update_setting(key, kind, value)
      setting = Setting.find_by!(key: key)

      patch adm_attribute_path(record_type: "setting", id: setting.id),
            params: {
              attribute: "value",
              kind: kind,
              field_token: Adm::AttributeEditorToken.generate(setting, "value", kind),
              setting: { value: value }
            }
    end

    it "changes the reminder interval" do
      update_setting("offers.reminder_interval", "select", "quarterly")

      expect(Setting["offers.reminder_interval"]).to eq "quarterly"
    end

    it "cannot switch the module on" do
      update_setting("process.offers", "boolean", "true")

      expect(Setting["process.offers"]).to be_blank
    end
  end
end
