module Verifications
  class CreateXML
    def self.create_verification_request(user_id, document_number)
      user = User.find(user_id)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request(id: user_id) {
          xml.vorname user.first_name
          xml.nachname user.last_name
          xml.geburtsdatum user.date_of_birth.strftime("%d.%m.%Y")
          xml.plz user.plz
          if user.document_type == 'card'
            xml.panr document_number
          elsif user.document_type == 'pass'
            xml.rpnr document_number
          end
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")

      file_path = Rails.application.secrets.bam_xml_dir

      filename = file_path + current_time + '_' + user_id.to_s + '_'

      File.open("#{filename}RQ.xml",'w') {|f| f.write builder.to_xml}
      CheckUserVerificationRequestJob.perform_later(filename)
    end

    def self.create_verification_request_in_booth(residence, document_number)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request {
          xml.vorname residence.first_name
          xml.nachname residence.last_name
          xml.geburtsdatum residence.date_of_birth.strftime("%d.%m.%Y")
          xml.plz residence.postal_code
          if residence.document_type == 'card'
            xml.panr document_number
          elsif residence.document_type == 'pass'
            xml.rpnr document_number
          end
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")

      file_path = Rails.application.secrets.bam_xml_dir

      filename = file_path + current_time + '_poll_officer_' + residence.officer.id.to_s + '_'

      File.open("#{filename}RQ.xml",'w') {|f| f.write builder.to_xml}
      filename
    end

    def self.create_verification_letter(user)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request(id: user.id) {
          xml.vorname user.first_name
          xml.nachname user.last_name
          xml.geburtsdatum user.date_of_birth.strftime("%d.%m.%Y")
          xml.plz user.plz
          xml.strasse user.street_name
          xml.hausnummer user.street_number
          xml.stadt user.city_name
          xml.letter_verification_code user.bam_letter_verification_code
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")

      file_path = Rails.application.secrets.bam_xml_code_dir

      filename = file_path + current_time + '_' + user.id.to_s
      File.open("#{filename}.xml",'w') {|f| f.write builder.to_xml}
      Rails.logger.info "File creted: #{filename}.xml"
      Mailer.residence_confirmation_code(user).deliver_later
    end
  end
end
