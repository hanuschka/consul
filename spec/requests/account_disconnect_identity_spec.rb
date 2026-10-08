require "rails_helper"

describe "Disconnecting a connected account", type: :request do
  let(:user) { create(:user) }
  let!(:identity) { Identity.create!(user: user, provider: "kobil", uid: "kobil-123") }

  before { login_as(user) }

  it "removes the identity and returns to the account page" do
    delete disconnect_identity_account_path(provider: "kobil")

    expect(response).to redirect_to(account_path)
    expect(flash[:notice]).to eq I18n.t("custom.account.connected_accounts.disconnected")
    expect(Identity.exists?(identity.id)).to be false
  end

  it "leaves other users' identities alone" do
    other = Identity.create!(user: create(:user), provider: "kobil", uid: "kobil-456")

    delete disconnect_identity_account_path(provider: "kobil")

    expect(Identity.exists?(other.id)).to be true
  end
end
