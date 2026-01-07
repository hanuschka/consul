module BundIdServices
  class RedirectRequestMaker < ApplicationService
    def initialize(user_id: nil, purpose: nil)
      @user_id = user_id
      @purpose = purpose
    end

    def call
      "#{Rails.application.secrets.bund_id[:idp_destination]}?#{request_params}"
    end

    private

      def request_params
        saml_request = CGI.escape(encode(deflate(signed_xml_document.to_s)))

        if @purpose.present?
          state = SecureRandom.hex(16)
          RelayState.create!(
            token: state,
            data: { user_id: @user_id, purpose: @purpose }
          )
          relay_state = CGI.escape(state)

          "SAMLRequest=#{saml_request}&RelayState=#{relay_state}"
        else
          "SAMLRequest=#{saml_request}"
        end
      end

      def signed_xml_document
        create_xml_document.sign_document(
          OpenSSL::PKey::RSA.new(settings[:private_key]),
          OpenSSL::X509::Certificate.new(settings[:certificate])
        )
      end

      def create_xml_document
        request_doc = XMLSecurity::Document.new

        root = request_doc.add_element "saml2p:AuthnRequest", {
          "xmlns:saml2p" => "urn:oasis:names:tc:SAML:2.0:protocol",
          "AssertionConsumerServiceURL" => settings[:assertion_consumer_service_url],
          "Destination" => settings[:idp_destination],
          "ForceAuthn" => "true",
          "ID" => "_#{SecureRandom.uuid}",
          "IsPassive" => "false",
          "IssueInstant" => Time.now.utc.iso8601,
          "ProtocolBinding" => "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
          "Version" => "2.0"
        }

        issuer = root.add_element "saml2:Issuer", {
          "xmlns:saml2" => "urn:oasis:names:tc:SAML:2.0:assertion"
        }
        issuer.text = settings[:issuer_id]

        extensons = root.add_element "saml2p:Extensions"
        akdb_authentication_request = extensons.add_element "akdb:AuthenticationRequest", {
          "xmlns:akdb" => "https://www.akdb.de/request/2018/09",
          "Version" => "2"
        }

        akdb_allowed_methods = akdb_authentication_request.add_element "akdb:AllowedMethods"
        akdb_allowed_method1 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
        akdb_allowed_method1.text = "eID"
        akdb_allowed_method2 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
        akdb_allowed_method2.text = "eIDAS"
        akdb_allowed_method3 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
        akdb_allowed_method3.text = "Benutzername"
        akdb_allowed_method4 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
        akdb_allowed_method4.text = "FINK"

        akdb_requested_attributes = akdb_authentication_request.add_element "akdb:RequestedAttributes"
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.18" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.3.6.1.4.1.25484.494450.3" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.3.6.1.4.1.25484.494450.2" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:0.9.2342.19200300.100.1.3" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.42" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.4" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.2.40.0.10.2.1.1.55" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.3.6.1.4.1.33592.1.3.5" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.16" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.7" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.2.40.0.10.2.1.1.225599" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.17" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.3.6.1.5.5.7.9.2" }
        akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.2.40.0.10.2.1.1.261.94" }

        akdb_display_information = akdb_authentication_request.add_element "akdb:DisplayInformation"
        classic_ui_version = akdb_display_information.add_element "classic-ui:Version", { "xmlns:classic-ui" => "https://www.akdb.de/request/2018/09/classic-ui/v1" }
        # classic_ui_purpose = classic_ui_version.add_element "classic-ui:Purpose"
        # classic_ui_purpose.text = "<h1>My HTML</h1>"
        classic_ui_organization_display_name = classic_ui_version.add_element "classic-ui:OrganizationDisplayName"
        classic_ui_organization_display_name.text = Setting["org_name"]
        classic_ui_lang = classic_ui_version.add_element "classic-ui:Lang"
        classic_ui_lang.text = "de"
        classic_ui_back_url = classic_ui_version.add_element "classic-ui:BackURL"
        classic_ui_back_url.text = Setting["url"]
        classic_ui_online_service_id = classic_ui_version.add_element "classic-ui:OnlineServiceID"
        classic_ui_online_service_id.text = Rails.application.secrets.bund_id[:online_service_id]

        akdb_authentication_request.add_element "akdb:Berechtigungszertifikat", { "Bundesland" => settings[:bundesland_code] }

        requested_authn_context = root.add_element "saml2p:RequestedAuthnContext", { "Comparison" => "minimum" }
        authn_context_class_ref = requested_authn_context.add_element "saml2:AuthnContextClassRef", { "xmlns:saml2" => "urn:oasis:names:tc:SAML:2.0:assertion" }
        authn_context_class_ref.text = "STORK-QAA-Level-1"

        request_doc
      end

      def deflate(inflated)
        Zlib::Deflate.deflate(inflated, 9)[2..-5]
      end

      def encode(string)
        Base64.strict_encode64(string)
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
