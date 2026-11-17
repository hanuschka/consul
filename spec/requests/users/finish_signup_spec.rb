require "rails_helper"

describe "Finishing an OAuth sign-up", type: :request do
  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
  end

  context "user who is not registering with OAuth" do
    let(:user) { create(:user, username: "regular", password: "Aa12345678!") }

    before { login_as(user) }

    it "redirects the form to the home page" do
      get finish_signup_path

      expect(response).to redirect_to(root_path)
    end

    it "does not change the account" do
      patch do_finish_signup_path, params: { user: { username: "changed",
                                                     email: "changed@consul.dev",
                                                     password: "Bb98765432!",
                                                     password_confirmation: "Bb98765432!" } }

      expect(response).to redirect_to(root_path)
      user.reload
      expect(user.username).to eq "regular"
      expect(user.unconfirmed_email).to be_nil
      expect(user.valid_password?("Aa12345678!")).to be true
    end
  end

  context "user registering with OAuth" do
    let(:user) { create(:user, username: "pending", password: "Aa12345678!", registering_with_oauth: true) }

    before { login_as(user) }

    it "finishes the sign-up with a new username" do
      patch do_finish_signup_path, params: { user: { username: "finished" } }

      user.reload
      expect(user.username).to eq "finished"
      expect(user.registering_with_oauth).to be false
    end

    it "ignores a password" do
      patch do_finish_signup_path, params: { user: { username: "finished",
                                                     password: "Bb98765432!",
                                                     password_confirmation: "Bb98765432!" } }

      expect(user.reload.valid_password?("Aa12345678!")).to be true
    end
  end
end
