require "rails_helper"

describe Sms::PhoneNumber do
  describe ".normalize" do
    {
      "0171 1234567" => "+491711234567",
      "0171/1234567" => "+491711234567",
      "0151-12345678" => "+4915112345678",
      "+49 176 12345678" => "+4917612345678",
      "+49 (0) 171 1234567" => "+491711234567",
      "0049 171 1234567" => "+491711234567",
      "+491711234567" => "+491711234567"
    }.each do |input, expected|
      it "turns #{input.inspect} into #{expected}" do
        expect(Sms::PhoneNumber.normalize(input)).to eq expected
      end
    end

    ["030 1234567", "+34 612345678", "612345678", "0171 12", "0171 1234567890", "", nil, "abc"].each do |input|
      it "rejects #{input.inspect}" do
        expect(Sms::PhoneNumber.normalize(input)).to be nil
      end
    end
  end
end
