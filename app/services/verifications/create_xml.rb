module Verifications
  class CreateXML
    def self.create_verification_request(user_id)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request(id: user_id) {
          xml.vorname 'Stefan'
          xml.nachname 'Saule'
          xml.geburtsdatum '28.09.1967'
          xml.plz 96050
          xml.panr 'N7JH8'
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")
      file_path = '/home/deploy/consul/validation/'
      # file_path = '/home/mike/verifications/'

      filename = file_path + current_time + '_' + user_id.to_s + '_' + 'RQ'

      File.open("#{filename}.xml",'w') {|f| f.write builder.to_xml}
      CheckUserVerificationRequestJob.perform_now(filename)
    end
  end
end
