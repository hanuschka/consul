unless OneLogin::RubySaml::VERSION == "1.18.1"
  raise "ruby-saml #{OneLogin::RubySaml::VERSION} is not the version config/initializers/" \
        "ruby_saml_rsa_pss.rb was written for; check whether it still applies before upgrading"
end

module RubySamlRsaPss
  RSA_PSS_SHA256 = "http://www.w3.org/2007/05/xmldsig-more#sha256-rsa-MGF1".freeze
  DS = { "ds" => XMLSecurity::BaseDocument::DSIG }.freeze

  def validate_signature(base64_cert, soft = true)
    cache_referenced_xml(soft) unless @processed
    return super unless rsa_pss_signature?

    return append_error("No Signature node found", soft) if @signature.nil?
    return append_error("No canonized SignedInfo ", soft) if @cached_signed_info.nil?
    return append_error("No Reference node found", soft) if @ref.nil?
    return append_error("No referenced XML", soft) if @referenced_xml.nil?

    digest_algorithm = algorithm(REXML::XPath.first(@ref, "./ds:DigestMethod", DS))
    digest_value = OneLogin::RubySaml::Utils.element_text(REXML::XPath.first(@ref, "./ds:DigestValue", DS))
    digest_matches = digest_value && digest_algorithm.digest(@referenced_xml) == Base64.decode64(digest_value)
    return append_error("Digest mismatch", soft) unless digest_matches

    cert = OpenSSL::X509::Certificate.new(Base64.decode64(base64_cert))
    verified = cert.public_key.verify_pss("SHA256", @signature, @cached_signed_info,
                                          salt_length: :auto, mgf1_hash: "SHA256")
    return append_error("Key validation error", soft) unless verified

    true
  end

  private

    def rsa_pss_signature?
      signature = REXML::XPath.first(@working_copy, "//ds:Signature", DS)
      method = signature && REXML::XPath.first(signature, "./ds:SignedInfo/ds:SignatureMethod", DS)
      method&.attribute("Algorithm")&.value == RSA_PSS_SHA256
    end
end

XMLSecurity::SignedDocument.prepend(RubySamlRsaPss)
