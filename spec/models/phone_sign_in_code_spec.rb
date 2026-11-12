require "rails_helper"

describe PhoneSignInCode do
  let(:phone) { "+491711234567" }
  let(:ip) { "203.0.113.5" }

  before do
    Sms::Adapters::Log.deliveries.clear
    allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(123_456, 654_321)
  end

  def sent_code
    Sms::Adapters::Log.deliveries.last[:text][/\b\d{6}\b/]
  end

  describe ".issue" do
    it "sends one German SMS with a six-digit code and stores no plain number or code" do
      expect(PhoneSignInCode.issue(phone: phone, ip: ip)).to eq :sent

      expect(Sms::Adapters::Log.deliveries.size).to eq 1
      expect(Sms::Adapters::Log.deliveries.first[:to]).to eq phone
      expect(sent_code).to eq "123456"

      record = PhoneSignInCode.last
      expect(record.attributes.values.map(&:to_s)).not_to include(phone, sent_code, ip)
    end

    it "refuses a second code for the same number within the cooldown" do
      PhoneSignInCode.issue(phone: phone, ip: ip)

      expect(PhoneSignInCode.issue(phone: phone, ip: ip)).to eq :rate_limited
      expect(Sms::Adapters::Log.deliveries.size).to eq 1
    end

    it "limits code requests per number and hour" do
      PhoneSignInCode::MAX_PER_PHONE_PER_HOUR.times do |i|
        travel_to((i * 2).minutes.from_now) { PhoneSignInCode.issue(phone: phone, ip: "198.51.100.#{i}") }
      end

      travel_to(15.minutes.from_now) do
        expect(PhoneSignInCode.issue(phone: phone, ip: ip)).to eq :rate_limited
      end
    end

    it "limits code requests per IP and hour" do
      PhoneSignInCode::MAX_PER_IP_PER_HOUR.times do |i|
        PhoneSignInCode.issue(phone: "+4917112345#{i.to_s.rjust(2, "0")}", ip: ip)
      end

      expect(PhoneSignInCode.issue(phone: phone, ip: ip)).to eq :rate_limited
    end

    it "keeps no code when the provider rejects the SMS" do
      allow(Sms::Gateway).to receive(:deliver).and_return(Sms::Result.failure("HTTP 400"))

      expect(PhoneSignInCode.issue(phone: phone, ip: ip)).to eq :delivery_failed
      expect(PhoneSignInCode.count).to eq 0
    end

    it "deletes codes older than a day" do
      travel_to(2.days.ago) { PhoneSignInCode.issue(phone: "+4915112345678", ip: ip) }

      PhoneSignInCode.issue(phone: phone, ip: ip)

      expect(PhoneSignInCode.count).to eq 1
    end
  end

  describe ".verify" do
    before { PhoneSignInCode.issue(phone: phone, ip: ip) }

    it "accepts the correct code once" do
      code = sent_code

      expect(PhoneSignInCode.verify(phone: phone, code: code)).to eq :verified
      expect(PhoneSignInCode.verify(phone: phone, code: code)).to eq :expired
    end

    it "rejects a wrong code" do
      expect(PhoneSignInCode.verify(phone: phone, code: "999999")).to eq :invalid
    end

    it "ignores spaces inside the code" do
      expect(PhoneSignInCode.verify(phone: phone, code: " 123 456 ")).to eq :verified
    end

    it "rejects a code after its validity period" do
      code = sent_code

      travel_to((PhoneSignInCode::VALIDITY + 1.second).from_now) do
        expect(PhoneSignInCode.verify(phone: phone, code: code)).to eq :expired
      end
    end

    it "locks the code after too many wrong attempts" do
      code = sent_code
      PhoneSignInCode::MAX_ATTEMPTS.times { PhoneSignInCode.verify(phone: phone, code: "999999") }

      expect(PhoneSignInCode.verify(phone: phone, code: code)).to eq :expired
    end

    it "only accepts the newest code for a number" do
      travel_to(2.minutes.from_now) do
        PhoneSignInCode.issue(phone: phone, ip: ip)

        expect(PhoneSignInCode.verify(phone: phone, code: "123456")).to eq :invalid
        expect(PhoneSignInCode.verify(phone: phone, code: "654321")).to eq :verified
      end
    end

    it "does not accept a code for another number" do
      expect(PhoneSignInCode.verify(phone: "+4915112345678", code: sent_code)).to eq :expired
    end
  end
end
