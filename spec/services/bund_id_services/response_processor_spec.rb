require "rails_helper"

describe BundIdServices::ResponseProcessor do
  before { stub_bund_id_secrets }

  def process(response, request_id: "_request")
    BundIdServices::ResponseProcessor.call(response, request_id: request_id)
  end

  it "returns the identity from a response signed by BundID" do
    auth = process(bund_id_saml_response)

    expect(auth.provider).to eq("bund_id")
    expect(auth.uid).to eq("bpk2-erika-mustermann")
    expect(auth.info.first_name).to eq("Erika")
    expect(auth.info.last_name).to eq("Mustermann")
    expect(auth.extra.raw_info.postal_code).to eq("51147")
    expect(auth.extra.raw_info.verification_level).to eq("STORK-QAA-Level-3")
  end

  it "rejects a response signed by someone other than BundID" do
    response = bund_id_saml_response(signed_by: :attacker)

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /Invalid Signature/)
  end

  it "accepts a response signed with plain RSA-SHA256" do
    auth = process(bund_id_saml_response(rsa_pss: false))

    expect(auth.uid).to eq("bpk2-erika-mustermann")
  end

  it "rejects a response signed by someone else who embeds BundID's certificate" do
    response = bund_id_saml_response(signed_by: :attacker, embedded_certificate_of: :bund_id)

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /Invalid Signature/)
  end

  it "rejects an RSA-SHA256 response signed by someone other than BundID" do
    response = bund_id_saml_response(signed_by: :attacker, rsa_pss: false)

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /Invalid Signature/)
  end

  it "rejects an unsigned response" do
    response = bund_id_saml_response(signed_by: nil)

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /Signature/)
  end

  it "rejects a response that was altered after BundID signed it" do
    xml = Base64.decode64(bund_id_saml_response).sub(BundIdSamlHelpers::ACS_URL, "https://consul.test/elsewhere")

    expect { process(Base64.strict_encode64(xml)) }.to raise_error(described_class::InvalidResponse)
  end

  it "rejects a response past its validity window" do
    response = bund_id_saml_response(valid_until: 5.minutes.from_now)

    travel(6.minutes) do
      expect { process(response) }.to raise_error(described_class::InvalidResponse, /NotOnOrAfter/)
    end
  end

  it "rejects a response addressed to a different service" do
    response = bund_id_saml_response(audience: "https://other-service.test")

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /Audience/)
  end

  it "rejects a response that answers a different request" do
    response = bund_id_saml_response(in_response_to: "_another_request")

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /InResponseTo/)
  end

  it "rejects a response that is not XML" do
    response = Base64.strict_encode64("<samlp:Response><unclosed>")

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /Malformed/)
    expect { process("not even base64") }.to raise_error(described_class::InvalidResponse, /Malformed/)
  end

  it "rejects a response when there is no request to match it against" do
    response = bund_id_saml_response

    expect { process(response, request_id: nil) }.to raise_error(described_class::InvalidResponse)
  end

  it "rejects a response sent to a different endpoint" do
    response = bund_id_saml_response(destination: "https://other-service.test/sp/SAML2/POST")

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /received at/)
  end

  it "rejects a response from a different identity provider" do
    response = bund_id_saml_response(issuer: "https://other-idp.test")

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /issuer/)
  end

  it "accepts a response that leaves out optional attributes" do
    auth = process(bund_id_saml_response(identity: { uid: "bpk2-erika-mustermann" }))

    expect(auth.uid).to eq("bpk2-erika-mustermann")
    expect(auth.info.email).to be_nil
    expect(auth.extra.raw_info.postal_code).to be_nil
  end

  it "rejects a response without a BundID uid" do
    response = bund_id_saml_response(identity: bund_id_identity(uid: nil))

    expect { process(response) }.to raise_error(described_class::InvalidResponse, /uid/)
  end
end
