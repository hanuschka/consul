module Verifications
  class CheckXML
    def self.check_verification_request(responce)
      file = File.open(responce)
      doc = Nokogiri::XML(file)

      user_id = doc.at_xpath('request')[:id]
      user = User.find_by(id: user_id)
      result = doc.at_xpath('request').at_xpath('kombi').text

      if result == "true"
        Mailer.residence_confirmed(user).deliver_later
      elsif result == 'false'
        errors = []
        errors.push("Vorname") if doc.at_xpath('request').at_xpath('vorname').text == 'false'
        errors.push("Nachname") if doc.at_xpath('request').at_xpath('nachname').text == 'false'
        errors.push("PLZ") if doc.at_xpath('request').at_xpath('plz').text == 'false'
        errors.push("Geburtsdatum") if doc.at_xpath('request').at_xpath('geburtsdatum').text == 'false'
        errors.push("Personalausweis") if doc.at_xpath('request').at_xpath('panr').text == 'false'
        errors.push("Reisepass") if doc.at_xpath('request').at_xpath('rpnr').text == 'false'
        Mailer.residence_not_confirmed(user, errors).deliver_later
      end
      file.close if file
    end
  end
end
