module RegisteredAddressServices
  class Matcher < ApplicationService
    STREET_ADDRESS_FORMAT = /\A(?<street_name>.+?)\s*(?<street_number>\d+)\s*(?<street_number_extension>[[:alpha:]]?)\s*\z/

    def initialize(street_address:, plz:, city_name:)
      @street_address = street_address.to_s.strip.sub(/[,\s]+\z/, "")
      @plz = plz.to_s.strip
      @city_name = city_name.to_s.strip
    end

    def call
      registered_address = find_registered_address
      registered_address ? attributes_from(registered_address) : received_attributes
    end

    private

      def parsed
        @parsed ||= @street_address.match(STREET_ADDRESS_FORMAT)
      end

      def street_name
        (parsed ? parsed[:street_name] : @street_address).sub(/[,\s]+\z/, "")
      end

      def street_number
        parsed&.[](:street_number)
      end

      def street_number_extension
        parsed&.[](:street_number_extension).presence
      end

      def find_registered_address
        return if parsed.nil? || @plz.blank? || @city_name.blank?

        street = RegisteredAddress::Street.unscoped.where(plz: @plz)
          .find { |candidate| normalize(candidate.name) == normalize(street_name) }
        return if street.nil?

        street.registered_addresses.includes(:registered_address_city).find do |address|
          address.street_number.to_s.strip == street_number &&
            address.street_number_extension.to_s.strip.downcase == street_number_extension.to_s.downcase &&
            normalize_city(address.registered_address_city.name) == normalize_city(@city_name)
        end
      end

      def normalize_city(name)
        name.to_s.downcase.gsub("ß", "ss").gsub(/\s+/, " ").strip
      end

      def normalize(name)
        name.to_s.downcase.strip
          .gsub("ß", "ss")
          .tr("-", " ")
          .gsub(/\s+/, " ")
          .sub(/str\.?\z/, "strasse")
      end

      def attributes_from(registered_address)
        {
          registered_address_id: registered_address.id,
          street_name: registered_address.registered_address_street.name,
          street_number: registered_address.street_number,
          street_number_extension: registered_address.street_number_extension,
          plz: registered_address.registered_address_street.plz,
          city_name: registered_address.registered_address_city.name
        }
      end

      def received_attributes
        {
          registered_address_id: nil,
          street_name: capitalize_words(street_name.presence),
          street_number: street_number,
          street_number_extension: street_number_extension,
          plz: @plz.presence,
          city_name: capitalize_words(@city_name.presence)
        }
      end

      def capitalize_words(text)
        text&.split(/([\s-])/)&.map(&:capitalize)&.join
      end
  end
end
