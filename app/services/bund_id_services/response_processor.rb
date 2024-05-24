module BundIdServices
  class ResponseProcessor < ApplicationService
    ASSERTION = "urn:oasis:names:tc:SAML:2.0:assertion".freeze
    PROTOCOL  = "urn:oasis:names:tc:SAML:2.0:protocol".freeze

    def initialize(response)
      @response = response
    end

    def call
      decoded = Base64.decode64(@response)
      document = XMLSecurity::SignedDocument.new(decoded)
      @decrypted_document = decrypt_assertion_from_document(document)
      formatted_attributes
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
              street_name: attributes[:street_name],
              locality_name: attributes[:locality_name],
              country: attributes[:country],
              postal_code: attributes[:postal_code],
              place_of_birth: attributes[:place_of_birth],
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

          attribute_names.each do |k, v|
            attrs[k] = get_attribute_value(v)
          end

          attrs
        end
      end

      def attribute_names
        {
          uid: "urn:oid:1.3.6.1.4.1.25484.494450.3",
          auth_method: "urn:oid:1.3.6.1.4.1.25484.494450.2",
          email_address: "urn:oid:0.9.2342.19200300.100.1.3",
          first_name: "urn:oid:2.5.4.42",
          last_name: "urn:oid:2.5.4.4",
          date_of_birth: "urn:oid:1.2.40.0.10.2.1.1.55",
          gender: "urn:oid:1.3.6.1.4.1.33592.1.3.5",
          street_name: "urn:oid:2.5.4.16",
          locality_name: "urn:oid:2.5.4.7",
          country: "urn:oid:1.2.40.0.10.2.1.1.225599",
          postal_code: "urn:oid:2.5.4.17",
          place_of_birth: "urn:oid:1.3.6.1.5.5.7.9.2",
          verification_level: "urn:oid:1.2.40.0.10.2.1.1.261.94"
        }
      end

      def get_attribute_value(name)
        REXML::XPath.first(
          @decrypted_document,
          "/p:Response[@ID=$id]/a:Assertion/a:AttributeStatement/a:Attribute[@Name=$name]/a:AttributeValue",
          { "p" => PROTOCOL, "a" => ASSERTION },
          { "id" => @decrypted_document.signed_element_id, "name" => name }
        ).text
      end

      def decrypt_assertion_from_document(document_copy)
        response_node = REXML::XPath.first(
          document_copy,
          "/p:Response/",
          { "p" => PROTOCOL }
        )
        encrypted_assertion_node = REXML::XPath.first(
          document_copy,
          "(/p:Response/EncryptedAssertion/)|(/p:Response/a:EncryptedAssertion/)",
          { "p" => PROTOCOL, "a" => ASSERTION }
        )
        response_node.add(decrypt_assertion(encrypted_assertion_node))
        encrypted_assertion_node.remove
        XMLSecurity::SignedDocument.new(response_node.to_s)
      end

      def decrypt_assertion(encrypted_assertion_node)
        decrypt_element(encrypted_assertion_node, /(.*<\/(\w+:)?Assertion>)/m)
      end

      def decrypt_element(encrypt_node, rgrex)
        node_header = '<node xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">'

        elem_plaintext = OneLogin::RubySaml::Utils.decrypt_data(
          encrypt_node, OpenSSL::PKey::RSA.new(format_private_key(settings[:private_key]))
        ).match(rgrex)[0]

        elem_plaintext = node_header + elem_plaintext + "</node>"

        doc = REXML::Document.new(elem_plaintext)
        doc.root[0]
      end

      def format_private_key(key)
        # don't try to format an encoded private key or if is empty
        return key if key.nil? || key.empty? || key.match(/\x0d/)

        # is this an rsa key?
        rsa_key = key.match("RSA PRIVATE KEY")
        key = key.gsub(/\-{5}\s?(BEGIN|END)( RSA)? PRIVATE KEY\s?\-{5}/, "")
        key = key.gsub(/\n/, "")
        key = key.gsub(/\r/, "")
        key = key.gsub(/\s/, "")
        key = key.scan(/.{1,64}/)
        key = key.join("\n")
        key_label = rsa_key ? "RSA PRIVATE KEY" : "PRIVATE KEY"
        "-----BEGIN #{key_label}-----\n#{key}\n-----END #{key_label}-----"
      end

      def settings
        secrets = Rails.application.secrets.bund_id

        secrets.merge(
          private_key: File.read(secrets[:private_key_path]),
          certificate: File.read(secrets[:certificate_path])
        )
      end
  end
end
