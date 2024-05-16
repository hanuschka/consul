module BundIdServices
  class SecondPostRequestMaker < ApplicationService
    def call
      request = OneLogin::RubySaml::Authrequest.new
      request.create(saml_settings).split("?SAMLRequest=")[1]
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

    def saml_settings
      settings = OneLogin::RubySaml::Settings.new

      settings.assertion_consumer_service_url = "https://funky-quality-clam.ngrok-free.app/sp/SAML2/POST"
      settings.sp_entity_id                   = "https://funky-quality-clam.ngrok-free.app/sp"
      settings.idp_entity_id                  = "https://int.id.bund.de/idp"
      settings.idp_sso_service_url            = "https://int.id.bund.de/idp/profile/SAML2/POST/SSO"
      settings.idp_sso_service_binding        = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" # or :post, :redirect
      # settings.idp_cert_fingerprint           = OneLoginAppCertFingerPrint
      # settings.idp_cert_fingerprint_algorithm = "http://www.w3.org/2000/09/xmldsig#sha1"
      # settings.name_identifier_format         = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"

      # Optional for most SAML IdPs
      settings.authn_context = "urn:oasis:names:tc:SAML:2.0:assertion"

      settings.certificate = File.read("/home/mike/Documents/bund_id_development/cert/cert.pem")
      settings.private_key = File.read("/home/mike/Documents/bund_id_development/cert/key.pem")
      settings.security[:authn_requests_signed] = true

      settings
    end
  end
end
