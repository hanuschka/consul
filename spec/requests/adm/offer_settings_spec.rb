require "rails_helper"

describe "Angebote settings in /adm", type: :request do
  let(:admin) { create(:administrator).user }
  let(:user) { create(:user) }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["process.offers"] = false
  end

  it "shows the module switch to an administrator" do
    login_as(admin)

    get adm_offers_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("setting.process.offers"))
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
end
