module Verifications
  class CreateXML
    def self.create_verification_request(user_id, doc_type, doc_number)
      user = User.find(user_id)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request(id: user_id) {
          xml.vorname user.first_name
          xml.nachname user.last_name
          xml.geburtsdatum user.date_of_birth.strftime("%d.%m.%Y")
          xml.plz user.plz
          if doc_type == 'card'
            xml.panr doc_number
          elsif doc_type == 'pass'
            xml.rpnr doc_number
          end
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")

      # file_path = '/home/deploy/consul/validation/'
      file_path = '/home/mike/verifications/'

      filename = file_path + current_time + '_' + user_id.to_s + '_'

      File.open("#{filename + "RQ"}.xml",'w') {|f| f.write builder.to_xml}
      CheckUserVerificationRequestJob.perform_later(filename)
    end

    def self.create_verification_letter(user)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request(id: user.id) {
          xml.vorname user.first_name
          xml.nachname user.last_name
          xml.geburtsdatum user.date_of_birth.strftime("%d.%m.%Y")
          xml.plz user.plz
          xml.strasse user.street_name
          xml.hausnummer user.house_number
          xml.stadt user.city_name
          xml.letter_verification_code = user.bam_letter_verification_code
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")

      # file_path = '/home/deploy/consul/validation/'
      file_path = '/home/mike/verifications/'

      filename = file_path + current_time + '_' + user.id.to_s
      File.open("#{filename}.xml",'w') {|f| f.write builder.to_xml}
      Mailer.residence_confirmation_code(user).deliver_later
    end
  end
end
