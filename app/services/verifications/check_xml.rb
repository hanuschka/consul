module Verifications
  class CheckXML
    def self.check_verification_request(responce)
      # 
      # responce = "/home/mike/verifications/21070212202033_1_"
      #

      file = File.open(responce + "AN.xml")
      doc = Nokogiri::XML(file)

      user_id = doc.at_xpath('request')[:id]
      user = User.find_by(id: user_id)
      result = doc.at_xpath('request').at_xpath('kombi').text

      if result == "true"
        geozone = Geozone.find_by(external_code: user.plz)
        document_number = (user.document_type == 'card') ? "ABCD_#{user.id}" : "DCBA_#{user.id}"
        bam_unique_stamp = ::Calculations::User.bam_unique_stamp(user.first_name, user.last_name, user.date_of_birth.year, user.date_of_birth.month, user.date_of_birth.day, user.plz)
        user.update(verified_at: Time.now, geozone: geozone, document_number: document_number, bam_unique_stamp: bam_unique_stamp)
        Mailer.residence_confirmed(user).deliver_later
        user.take_votes_if_erased_exists(bam_unique_stamp)
      elsif result == 'false'
        errors = []
        errors.push("Vorname") if doc.at_xpath('request').at_xpath('vorname').text == 'false'
        errors.push("Nachname") if doc.at_xpath('request').at_xpath('nachname').text == 'false'
        errors.push("PLZ") if doc.at_xpath('request').at_xpath('plz').text == 'false'
        errors.push("Geburtsdatum") if doc.at_xpath('request').at_xpath('geburtsdatum').text == 'false'
        errors.push("Wohnungsart muss mit einer der drei Arten übereinstimmen: alleinige Wohnung, Hauptwohnung oder Nebenwohnung") if doc.at_xpath('request').at_xpath('art').text == 'false'

        if doc.at_xpath('request').at_xpath('panr').present? && doc.at_xpath('request').at_xpath('panr').text == 'false'
          errors.push("Dokumenten-ID")
        end

        if doc.at_xpath('request').at_xpath('rpnr').present? && doc.at_xpath('request').at_xpath('rpnr').text == 'false'
          errors.push("Reisepass ID")
        end

        Mailer.residence_not_confirmed(user, errors).deliver_later
      end
      file.close if file
    end

    def self.check_verification_request_in_booth(responce)
      #
      # responce = "/home/mike/verifications/21070212202033_1_"
      #


      return {result: 'no_response'} unless File.exist?(responce + "AN.xml")
      file = File.open(responce + "AN.xml")
      doc = Nokogiri::XML(file)

      result = doc.at_xpath('request').at_xpath('kombi').text

      errors = []
      errors.push(:first_name) if doc.at_xpath('request').at_xpath('vorname').text == 'false'
      errors.push(:last_name) if doc.at_xpath('request').at_xpath('nachname').text == 'false'
      errors.push(:postal_code) if doc.at_xpath('request').at_xpath('plz').text == 'false'
      errors.push(:date_of_birth) if doc.at_xpath('request').at_xpath('geburtsdatum').text == 'false'

      if doc.at_xpath('request').at_xpath('panr').present? && doc.at_xpath('request').at_xpath('panr').text == 'false'
        errors.push(:document_number)
      end

      if doc.at_xpath('request').at_xpath('rpnr').present? && doc.at_xpath('request').at_xpath('rpnr').text == 'false'
        errors.push(:document_number)
      end

      file.close if file
      { result: result, errors: errors }
    end
  end
end
