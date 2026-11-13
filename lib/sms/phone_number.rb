class Sms::PhoneNumber
  GERMAN_MOBILE = /\A\+491[5-7]\d{8,9}\z/

  def self.normalize(value)
    digits = value.to_s.gsub(%r{[\s/\-().]}, "")

    number = case digits
             when /\A\+49/ then digits
             when /\A0049/ then "+#{digits[2..]}"
             when /\A0/ then "+49#{digits[1..]}"
             end

    number = number&.sub(/\A\+490/, "+49")
    number if number&.match?(GERMAN_MOBILE)
  end
end
