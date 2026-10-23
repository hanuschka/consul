module BundIdServices
  class ResponseProcessor < ApplicationService
    class InvalidResponse < StandardError; end

    ALLOWED_CLOCK_DRIFT = 5

    ATTRIBUTE_NAMES = {
      uid: "urn:oid:1.3.6.1.4.1.25484.494450.3",
      auth_method: "urn:oid:1.3.6.1.4.1.25484.494450.2",
      email_address: "urn:oid:0.9.2342.19200300.100.1.3",
      first_name: "urn:oid:2.5.4.42",
      last_name: "urn:oid:2.5.4.4",
      date_of_birth: "urn:oid:1.2.40.0.10.2.1.1.55",
      gender: "urn:oid:1.3.6.1.4.1.33592.1.3.5",
      street_address: "urn:oid:2.5.4.16",
      locality_name: "urn:oid:2.5.4.7",
      postal_code: "urn:oid:2.5.4.17",
      verification_level: "urn:oid:1.2.40.0.10.2.1.1.261.94"
    }.freeze

    def initialize(response, request_id:)
      @response = response
      @request_id = request_id
    end

    def call
      raise InvalidResponse, "No SAML response" if @response.blank?
      raise InvalidResponse, "No BundID request to match the response against" if @request_id.blank?

      saml_response = OneLogin::RubySaml::Response.new(
        @response,
        settings: saml_settings,
        allowed_clock_drift: ALLOWED_CLOCK_DRIFT,
        matches_request_id: @request_id
      )
      raise InvalidResponse, saml_response.errors.join("; ") unless saml_response.is_valid?(true)

      @saml_attributes = saml_response.attributes
      raise InvalidResponse, "The response carries no BundID uid" if attributes[:uid].blank?

      OmniAuth::AuthHash.new(formatted_attributes)
    rescue IdpCertificates::Unavailable => e
      raise InvalidResponse, e.message
    rescue REXML::ParseException => e
      raise InvalidResponse, "Malformed SAML response: #{e.message.lines.first&.strip}"
    end

    private

      def formatted_attributes
        {
          provider: "bund_id",
          uid: attributes[:uid],
          info: {
            email: attributes[:email_address],
            name: [attributes[:first_name], attributes[:last_name]].join(" "),
            first_name: attributes[:first_name],
            last_name: attributes[:last_name],
            verified_email: attributes[:email_address]
          },
          extra: {
            raw_info: {
              id: attributes[:uid],
              name: [attributes[:first_name], attributes[:last_name]].join(" "),
              first_name: attributes[:first_name],
              last_name: attributes[:last_name],
              gender: formatted_gender(attributes[:gender]),
              email: attributes[:email_address],
              auth_method: attributes[:auth_method],
              date_of_birth: attributes[:date_of_birth],
              street_address: attributes[:street_address],
              locality_name: attributes[:locality_name],
              postal_code: attributes[:postal_code],
              verification_level: attributes[:verification_level]
            }
          }
        }
      end

      def formatted_gender(gender_attribute)
        if gender_attribute == "1"
          "male"
        elsif gender_attribute == "2"
          "female"
        else
          nil
        end
      end

      def attributes
        @attributes ||= begin
          attrs = {}

          ATTRIBUTE_NAMES.each do |k, v|
            attrs[k] = @saml_attributes[v]
          end

          attrs
        end
      end

      def saml_settings
        secrets = Rails.application.secrets.bund_id

        OneLogin::RubySaml::Settings.new.tap do |settings|
          settings.idp_entity_id = secrets[:idp_url]
          settings.idp_cert_multi = { signing: IdpCertificates.call(secrets[:idp_url]) }
          settings.sp_entity_id = secrets[:issuer_id]
          settings.assertion_consumer_service_url = secrets[:assertion_consumer_service_url]
          settings.private_key = File.read(secrets[:private_key_path])
          settings.certificate = File.read(secrets[:certificate_path])
        end
      end
  end
end
