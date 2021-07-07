module Verifications
  class CheckXML
    def self.check_verification_request
      success_responce = "/home/deploy/consul/validation/21070212202033_1234_AN.xml"
      failed_responce = "/home/deploy/consul/validation/21070212302033_2345_AN.xml"
      no_responce = "/home/deploy/consul/validation/2107021230203312_2345_AN.xml"

      file = File.open(no_responce)
      doc = Nokogiri::XML(file)
      response = doc.at_xpath('request').at_xpath('kombi').text
      if response == "true"
        User.first.touch
      elsif response == 'false'
        User.first.touch
      end
    ensure
      file.close if file
    end
  end
end
