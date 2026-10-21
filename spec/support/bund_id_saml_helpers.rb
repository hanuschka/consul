module BundIdSamlHelpers
  IDP_URL = "https://idp.bund-id.test".freeze
  SP_ENTITY_ID = "https://consul.test".freeze
  ACS_URL = "https://consul.test/sp/SAML2/POST".freeze

  def self.keypair(name)
    @keypairs ||= {}
    @keypairs[name] ||= begin
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=#{name}")
      cert.public_key = key.public_key
      cert.not_before = 1.day.ago
      cert.not_after = 10.years.from_now
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      [key, cert]
    end
  end

  def self.secrets_dir
    @secrets_dir ||= Dir.mktmpdir("bund_id_spec").tap do |dir|
      File.write(File.join(dir, "sp_key.pem"), keypair(:service_provider).first.to_pem)
      File.write(File.join(dir, "sp_cert.pem"), keypair(:service_provider).last.to_pem)
    end
  end

  def stub_bund_id_secrets
    dir = BundIdSamlHelpers.secrets_dir

    allow(BundIdServices::IdpCertificates).to receive(:call).with(IDP_URL)
                                                         .and_return([bund_id_certificate(:bund_id)])
    allow(Rails.application.secrets).to receive(:bund_id).and_return(
      idp_url: IDP_URL,
      idp_destination: "#{IDP_URL}/sso",
      online_service_id: "consul-test",
      bundesland_code: "09",
      issuer_id: SP_ENTITY_ID,
      assertion_consumer_service_url: ACS_URL,
      private_key_path: File.join(dir, "sp_key.pem"),
      certificate_path: File.join(dir, "sp_cert.pem")
    )
  end

  def bund_id_certificate(name)
    Base64.strict_encode64(BundIdSamlHelpers.keypair(name).last.to_der)
  end

  def bund_id_metadata(entity_id: IDP_URL, certificates: [bund_id_certificate(:bund_id)])
    key_descriptors = certificates.map do |certificate|
      <<~XML
        <md:KeyDescriptor use="signing">
          <ds:KeyInfo><ds:X509Data><ds:X509Certificate>#{certificate}</ds:X509Certificate></ds:X509Data></ds:KeyInfo>
        </md:KeyDescriptor>
      XML
    end

    <<~XML
      <md:EntitiesDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
        xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
        <md:EntityDescriptor entityID="#{entity_id}">
          <md:IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
            #{key_descriptors.join}
            <md:SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
              Location="#{entity_id}/profile/SAML2/Redirect/SSO"/>
          </md:IDPSSODescriptor>
        </md:EntityDescriptor>
      </md:EntitiesDescriptor>
    XML
  end

  def bund_id_identity(overrides = {})
    {
      uid: "bpk2-erika-mustermann",
      auth_method: "eID",
      email_address: "erika@example.org",
      first_name: "Erika",
      last_name: "Mustermann",
      date_of_birth: "1964-08-12",
      street_address: "Heidestraße 17",
      locality_name: "Köln",
      postal_code: "51147",
      verification_level: "STORK-QAA-Level-3"
    }.merge(overrides)
  end

  def bund_id_saml_response(identity: bund_id_identity, signed_by: :bund_id,
                            embedded_certificate_of: signed_by, rsa_pss: true, issuer: IDP_URL,
                            audience: SP_ENTITY_ID, destination: ACS_URL, in_response_to: "_request",
                            valid_until: 5.minutes.from_now)
    assertion = bund_id_assertion(identity, issuer: issuer, audience: audience,
                                            in_response_to: in_response_to, valid_until: valid_until)

    document = XMLSecurity::Document.new(<<~XML)
      <samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
        xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" ID="_#{SecureRandom.hex(16)}" Version="2.0"
        IssueInstant="#{Time.current.utc.iso8601}" Destination="#{destination}" InResponseTo="#{in_response_to}">
        <saml:Issuer>#{issuer}</saml:Issuer>
        <samlp:Status><samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success"/></samlp:Status>
        #{bund_id_encrypted_assertion(assertion)}
      </samlp:Response>
    XML

    return Base64.strict_encode64(document.to_s) unless signed_by

    key = BundIdSamlHelpers.keypair(signed_by).first
    cert = BundIdSamlHelpers.keypair(embedded_certificate_of).last
    signed = document.sign_document(
      key, cert, XMLSecurity::Document::RSA_SHA256, XMLSecurity::Document::SHA256
    )
    xml = rsa_pss ? resign_with_rsa_pss(signed.to_s, key) : signed.to_s

    Base64.strict_encode64(xml)
  end

  private

    def resign_with_rsa_pss(xml, key)
      namespaces = { "ds" => XMLSecurity::BaseDocument::DSIG }
      document = Nokogiri::XML(xml.sub(XMLSecurity::Document::RSA_SHA256, RubySamlRsaPss::RSA_PSS_SHA256))
      signed_info = document.at_xpath("//ds:Signature/ds:SignedInfo", namespaces)
      canonical = signed_info.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
      signature = key.sign_pss("SHA256", canonical, salt_length: :digest, mgf1_hash: "SHA256")
      signature_value = document.at_xpath("//ds:Signature/ds:SignatureValue", namespaces)
      signature_value.content = Base64.strict_encode64(signature)
      document.to_xml
    end

    def bund_id_assertion(identity, issuer:, audience:, in_response_to:, valid_until:)
      now = Time.current.utc
      attributes = identity.compact.map do |key, value|
        name = BundIdServices::ResponseProcessor::ATTRIBUTE_NAMES.fetch(key)
        value_xml = "<saml:AttributeValue>#{CGI.escapeHTML(value)}</saml:AttributeValue>"
        %(<saml:Attribute Name="#{name}">#{value_xml}</saml:Attribute>)
      end

      <<~XML
        <saml:Assertion xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" ID="_#{SecureRandom.hex(16)}"
          Version="2.0" IssueInstant="#{now.iso8601}">
          <saml:Issuer>#{issuer}</saml:Issuer>
          <saml:Subject>
            <saml:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:transient">_#{SecureRandom.hex(8)}</saml:NameID>
            <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
              <saml:SubjectConfirmationData NotOnOrAfter="#{valid_until.utc.iso8601}" Recipient="#{ACS_URL}"
                InResponseTo="#{in_response_to}"/>
            </saml:SubjectConfirmation>
          </saml:Subject>
          <saml:Conditions NotBefore="#{(now - 1.minute).iso8601}" NotOnOrAfter="#{valid_until.utc.iso8601}">
            <saml:AudienceRestriction><saml:Audience>#{audience}</saml:Audience></saml:AudienceRestriction>
          </saml:Conditions>
          <saml:AuthnStatement AuthnInstant="#{now.iso8601}" SessionIndex="_#{SecureRandom.hex(8)}">
            <saml:AuthnContext>
              <saml:AuthnContextClassRef>#{identity[:verification_level] || "STORK-QAA-Level-1"}</saml:AuthnContextClassRef>
            </saml:AuthnContext>
          </saml:AuthnStatement>
          <saml:AttributeStatement>#{attributes.join}</saml:AttributeStatement>
        </saml:Assertion>
      XML
    end

    def bund_id_encrypted_assertion(assertion)
      cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
      symmetric_key = cipher.random_key
      iv = cipher.random_iv
      cipher.auth_data = ""
      cipher_value = Base64.strict_encode64(iv + cipher.update(assertion) + cipher.final + cipher.auth_tag)

      sp_public_key = BundIdSamlHelpers.keypair(:service_provider).last.public_key
      encrypted_key = sp_public_key.public_encrypt(symmetric_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)

      <<~XML
        <saml:EncryptedAssertion>
          <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#" Type="http://www.w3.org/2001/04/xmlenc#Element">
            <xenc:EncryptionMethod Algorithm="http://www.w3.org/2009/xmlenc11#aes256-gcm"/>
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
              <xenc:EncryptedKey>
                <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p"/>
                <xenc:CipherData><xenc:CipherValue>#{Base64.strict_encode64(encrypted_key)}</xenc:CipherValue></xenc:CipherData>
              </xenc:EncryptedKey>
            </ds:KeyInfo>
            <xenc:CipherData><xenc:CipherValue>#{cipher_value}</xenc:CipherValue></xenc:CipherData>
          </xenc:EncryptedData>
        </saml:EncryptedAssertion>
      XML
    end
end

RSpec.configure do |config|
  config.include BundIdSamlHelpers
end
