require "rails_helper"

describe "Credentials page for phone accounts", type: :request do
  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  context "phone account" do
    let(:user) { User.create_phone_account!("+491711234567") }

    before { login_as(user) }

    it "redirects the edit page to the account page" do
      get edit_user_registration_path

      expect(response).to redirect_to(account_path)
    end

    it "redirects updates to the account page without changing anything" do
      put user_registration_path, params: { user: { email: "phone@consul.dev" } }

      expect(response).to redirect_to(account_path)
      expect(user.reload.unconfirmed_email).to be_nil
    end

    it "does not link to the credentials page" do
      get account_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(edit_user_registration_path)
    end
  end

  context "account with an e-mail address" do
    let(:user) { create(:user) }

    before { login_as(user) }

    it "shows the edit page" do
      get edit_user_registration_path

      expect(response).to have_http_status(:ok)
    end

    it "links to the credentials page" do
      get account_path

      expect(response.body).to include(edit_user_registration_path)
    end
  end
end
