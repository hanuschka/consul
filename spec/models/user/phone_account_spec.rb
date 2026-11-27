require "rails_helper"

describe User, "phone accounts" do
  let(:phone) { "+491711234567" }

  describe ".find_or_create_by_phone!" do
    it "creates a registered account without email or password" do
      user = User.find_or_create_by_phone!(phone)

      expect(user).to be_persisted
      expect(user).to be_phone_account
      expect(user.email).to be nil
      expect(user.encrypted_password).to be_blank
      expect(user.confirmed_phone).to eq phone
      expect(user).to be_confirmed
      expect(user).not_to be_guest
      expect(user).not_to be_verified
      expect(user.username).to match(/\A\S+-\d{6}\z/)
    end

    it "turns off per-event emails for the new account" do
      user = User.find_or_create_by_phone!(phone)

      expect(user.email_digest).to be false
      expect(user.email_on_direct_message).to be false
      expect(user.email_on_proposal_notification).to be false
    end

    it "skips the extended registration fields" do
      Setting["extra_fields.registration.extended"] = true
      Setting["extra_fields.registration.check_documents"] = true

      expect(User.find_or_create_by_phone!(phone)).to be_persisted
    end

    it "returns the existing account with that number" do
      existing = create(:user, confirmed_phone: phone)

      expect(User.find_or_create_by_phone!(phone)).to eq existing
      expect(User.where(confirmed_phone: phone).count).to eq 1
    end

    it "returns a blocked account instead of creating a new one" do
      blocked = create(:user, confirmed_phone: phone)
      blocked.hide

      expect(User.find_or_create_by_phone!(phone)).to eq blocked
    end

    it "lets several phone accounts exist without an email" do
      User.find_or_create_by_phone!(phone)

      expect(User.find_or_create_by_phone!("+4915112345678")).to be_persisted
    end
  end

  it "still requires an email for normal registrations" do
    user = build(:user, email: nil)

    expect(user).not_to be_valid
    expect(user.errors[:email]).not_to be_empty
  end

  it "deletes open sign-in codes for the number when the account is erased" do
    user = User.find_or_create_by_phone!(phone)
    PhoneSignInCode.issue(phone: phone, ip: "203.0.113.5")

    user.erase

    expect(PhoneSignInCode.for_phone(phone)).to be_empty
    expect(user.reload.confirmed_phone).to be nil
  end
end
