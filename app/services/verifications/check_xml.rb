module Verifications
  class CheckXML
    def self.check_verification_request(responce)
      success_responce = "/home/deploy/consul/validation/21070212202033_1234_AN.xml"
      failed_responce = "/home/deploy/consul/validation/21070212302033_2345_AN.xml"
      no_responce = "/home/deploy/consul/validation/21070212302033121_2345_AN.xml"

      # success_responce = "/home/mike/verifications/21070212202033_1234_AN.xml"
      # failed_responce = "/home/mike/verifications/21070212302033_2345_AN.xml"
      # no_responce = "/home/mike/verifications/2107021230203312_2345_AN.xml"

      file = File.open(responce)
      doc = Nokogiri::XML(file)
      response = doc.at_xpath('request').at_xpath('kombi').text
      if response == "true"
        User.first.touch
      elsif response == 'false'
        User.first.touch
      end
      file.close if file
    end
  end
end
