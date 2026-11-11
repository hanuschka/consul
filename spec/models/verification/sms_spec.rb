require "rails_helper"

describe Verification::Sms do
  let(:user) { create(:user) }

  before { Sms::Adapters::Log.deliveries.clear }

  it "sends the confirmation code to the normalised German mobile number" do
    sms = Verification::Sms.new(user: user, phone: "0171 1234567")

    expect(sms.save).to be_truthy
    expect(user.reload.unconfirmed_phone).to eq "+491711234567"
    expect(Sms::Adapters::Log.deliveries.size).to eq 1
    expect(Sms::Adapters::Log.deliveries.first[:to]).to eq "+491711234567"
    expect(Sms::Adapters::Log.deliveries.first[:text]).to include user.sms_confirmation_code
    expect(Lock.find_by(user: user).tries).to eq 1
  end

  it "rejects numbers that are not German mobile numbers" do
    sms = Verification::Sms.new(user: user, phone: "+34 612345678")

    expect(sms.save).to be false
    expect(sms.errors[:base]).not_to be_empty
    expect(Sms::Adapters::Log.deliveries).to be_empty
  end

  it "rejects a number already confirmed by another user in any notation" do
    create(:user, confirmed_phone: "+491711234567")
    sms = Verification::Sms.new(user: user, phone: "0171 1234567")

    expect(sms).not_to be_valid
    expect(sms.errors[:phone]).not_to be_empty
  end

  it "does not count a try when the provider rejects the SMS" do
    allow(Sms::Gateway).to receive(:deliver).and_return(Sms::Result.failure("HTTP 400"))
    sms = Verification::Sms.new(user: user, phone: "0171 1234567")

    expect(sms.save).to be false
    expect(sms.errors[:base]).not_to be_empty
    expect(Lock.find_by(user: user)).to be nil
  end
end
