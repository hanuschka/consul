require "rails_helper"

describe "Signing in with an identity of a blocked account", type: :request do
  let(:user) { create(:user, email: "blocked@example.org") }

  before do
    set_setting("feature.kobil_login", true)
    Identity.create!(user: user, provider: "kobil", uid: "kobil-erika")
    user.update_columns(hidden_at: Time.current)
    OmniAuth.config.mock_auth[:kobil] = OmniAuth::AuthHash.new(
      provider: "kobil", uid: "kobil-erika",
      info: { first_name: "Erika", last_name: "Mustermann", email: "erika@example.org" }
    )
  end

  after { OmniAuth.config.mock_auth[:kobil] = nil }

  it "refuses the login and creates no new account" do
    get user_kobil_omniauth_callback_path

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq(I18n.t("custom.users.omniauth.login_refused", provider: "KOBIL"))
    expect(User.with_hidden.count).to eq 1
    expect(Identity.find_by(provider: "kobil").user_id).to eq user.id
  end
end
