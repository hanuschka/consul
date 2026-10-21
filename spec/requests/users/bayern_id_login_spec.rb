require "rails_helper"

describe "BayernID first login", type: :request do
  let(:auth_hash) do
    {
      credentials: { id_token: "token" },
      info: {
        email: "lena.vogt@example.org",
        name: "Lena Vogt",
        first_name: "Lena",
        last_name: "Vogt"
      },
      extra: {
        raw_info: {
          authlevel: "STORK-QAA-Level-1",
          preferred_username: "lenavogt",
          birthdate: "1990-05-01",
          gender: "2",
          address: { postal_code: "80331" }
        }
      }
    }
  end

  before { OmniAuth.config.add_mock(:bayern_id, auth_hash) }
  after { OmniAuth.config.mock_auth[:bayern_id] = nil }

  it "creates the account even when the random part of the password has no digit or symbol" do
    allow(SecureRandom).to receive(:base64).and_call_original
    allow(SecureRandom).to receive(:base64).with(15).and_return("abcdefghijklmnopqrst")
    allow(SecureRandom).to receive(:alphanumeric).and_call_original
    allow(SecureRandom).to receive(:alphanumeric).with(20).and_return("abcdefghijklmnopqrst")

    expect { get user_bayern_id_omniauth_callback_path }.to change(User, :count).by(1)

    user = User.find_by!(email: "lena.vogt@example.org")
    expect(user).to have_attributes(keycloak_link: "lenavogt", first_name: "Lena", last_name: "Vogt")
    expect(response).to have_http_status(:redirect)
  end

  describe "a returning user" do
    it "stores the ID token of the new login for the logout hint" do
      user = create(:user, email: "lena.vogt@example.org", keycloak_link: "lenavogt",
                           keycloak_id_token: "old-token", terms_older_than_14: true)

      get user_bayern_id_omniauth_callback_path

      expect(user.reload.keycloak_id_token).to eq "token"
    end

    it "stores the ID token when the registration was not finished" do
      user = create(:user, email: "lena.vogt@example.org", username: "Lena Vogt", keycloak_link: "lenavogt",
                           registering_with_oauth: true, keycloak_id_token: "old-token",
                           terms_older_than_14: true)

      get user_bayern_id_omniauth_callback_path

      expect(user.reload.keycloak_id_token).to eq "token"
    end
  end
end
