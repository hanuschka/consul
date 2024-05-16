module BundIdServices
  class PostRequestMaker < ApplicationService
    def call
      # encode(deflate(signed_xml_document.to_s))
      # deflate(signed_xml_document.to_s)
      # signed_xml_document.to_s
      signed_xml_document
    end

    #private

    def vars
      {
        issuer_id: "https://funky-quality-clam.ngrok-free.app/sp",
        assertion_consumer_service_url: "https://funky-quality-clam.ngrok-free.app/sp/SAML2/POST",
        idp_destination: "https://int.id.bund.de/idp/profile/SAML2/POST/SSO",
        bundesland_code: "BY",
        private_key: File.read("/home/mike/Documents/bund_id_development/cert/key.pem"),
        certificate: File.read("/home/mike/Documents/bund_id_development/cert/cert.pem")
      }
    end

    def signed_xml_document
      create_xml_document.sign_document(
        OpenSSL::PKey::RSA.new(vars[:private_key]),
        OpenSSL::X509::Certificate.new(vars[:certificate])
      )
    end

    def create_xml_document
      request_doc = XMLSecurity::Document.new

      root = request_doc.add_element "saml2p:AuthnRequest", {
        "xmlns:saml2p" => "urn:oasis:names:tc:SAML:2.0:protocol",
        "AssertionConsumerServiceURL" => vars[:assertion_consumer_service_url],
        "Destination" => vars[:idp_destination],
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
      issuer.text = vars[:issuer_id]

      extensons = root.add_element "saml2p:Extensions"
      akdb_authentication_request = extensons.add_element "akdb:AuthenticationRequest", {
        "xmlns:akdb" => "https://www.akdb.de/request/2018/09",
        "Version" => "1"
      }

      akdb_allowed_methods = akdb_authentication_request.add_element "akdb:AllowedMethods"
      akdb_allowed_method1 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
      akdb_allowed_method1.text = "eID"
      akdb_allowed_method2 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
      akdb_allowed_method2.text = "Benutzername"
      akdb_allowed_method3 = akdb_allowed_methods.add_element "akdb:AuthnMethod"
      akdb_allowed_method3.text = "FINK"

      akdb_requested_attributes = akdb_authentication_request.add_element "akdb:RequestedAttributes"
      akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:2.5.4.18" }
      akdb_requested_attributes.add_element "akdb:RequestedAttribute", { "Name" => "urn:oid:1.3.6.1.4.1.25484.494450.3" }

      akdb_authentication_request.add_element "akdb:Berechtigungszertifikat", { "Bundesland" => vars[:bundesland_code] }

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
  end
end
