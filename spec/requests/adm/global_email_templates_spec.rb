require "rails_helper"

describe "System emails in /adm", type: :request do
  let(:admin) { create(:administrator).user }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    Setting["proposals.email_on_official_answer"] = nil
    Setting["email_templates.recipient_greeting"] = "username"
    login_as(admin)
  end

  it "offers the recipient greeting setting" do
    get adm_global_email_templates_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("setting.email_templates.recipient_greeting"))

    User::RECIPIENT_GREETING_OPTIONS.each do |option|
      expect(response.body).to include(%(value="#{option}"))
    end
  end
end
