require "rails_helper"

describe Offer::Provider do
  let(:provider) { create(:offer_provider) }

  describe "#add_email" do
    it "links an existing user right away" do
      user = create(:user, email: "anna@traeger.example")

      provider.add_email(" Anna@Traeger.example ")

      expect(provider.users).to eq [user]
      expect(provider.auto_join_emails).to be_empty
    end

    it "keeps the address of someone who has not registered yet" do
      provider.add_email("ben@traeger.example")

      expect(provider.users).to be_empty
      expect(provider.reload.auto_join_emails).to eq ["ben@traeger.example"]
    end

    it "links the account once it is registered with a stored address" do
      provider.add_email("ben@traeger.example")

      user = create(:user, email: "ben@traeger.example")

      expect(provider.reload.users).to eq [user]
      expect(provider.auto_join_emails).to be_empty
    end
  end

  describe "#remove_email" do
    it "unlinks the account and forgets the stored address" do
      linked = create(:user, email: "anna@traeger.example")
      provider.add_email(linked.email)
      provider.add_email("ben@traeger.example")

      provider.remove_email("ANNA@traeger.example")
      provider.remove_email("ben@traeger.example")

      expect(provider.reload.users).to be_empty
      expect(provider.auto_join_emails).to be_empty
    end
  end

  describe ".for_user" do
    it "finds the providers an account is linked to" do
      user = create(:user)
      provider.add_email(user.email)
      create(:offer_provider)

      expect(Offer::Provider.for_user(user)).to eq [provider]
    end

    it "ignores accounts that are not confirmed yet" do
      user = create(:user, :unconfirmed)
      provider.add_email(user.email)

      expect(Offer::Provider.for_user(user)).to be_empty
    end
  end

  it "cannot be deleted while it still has offers" do
    create(:offer, provider: provider)

    expect(provider.destroy).to be false
    expect(provider.errors[:base]).to be_present
  end
end
