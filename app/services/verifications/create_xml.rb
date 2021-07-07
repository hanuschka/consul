module Verifications
  class CreateXML
    def self.create_verification_request(user_id)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.request(id: user_id) {
          xml.vorname 'Thomas'
          xml.nachname 'Müller'
          xml.geburtsdatum 25.years.ago.strftime("%Y-%m-%d")
          xml.plz 12345
          xml.panr 12345678
        }
      end

      current_time = Time.now.to_time.strftime("%Y%m%d%H%M%S%L")
      file_path = '/home/deploy/consul/validation/'
      filename = file_path + current_time + '_' + user_id.to_s + '_' + 'RQ'

      File.open("#{filename}.xml",'w') {|f| f.write builder.to_xml}
    end
  end
end
