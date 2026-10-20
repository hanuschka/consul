require "rails_helper"

describe BundIdServices::IdpCertificates do
  let(:idp_url) { BundIdSamlHelpers::IDP_URL }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before { allow(Rails).to receive(:cache).and_return(cache) }

  def publish(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    allow(Net::HTTP).to receive(:start).and_return(response)
  end

  def bundid_down
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
  end

  it "reads the signing certificates from BundID's published metadata" do
    publish(bund_id_metadata)

    expect(BundIdServices::IdpCertificates.call(idp_url)).to eq([bund_id_certificate(:bund_id)])
  end

  it "accepts every signing certificate BundID publishes during a changeover" do
    certificates = [bund_id_certificate(:bund_id), bund_id_certificate(:bund_id_next)]
    publish(bund_id_metadata(certificates: certificates))

    expect(BundIdServices::IdpCertificates.call(idp_url)).to eq(certificates)
  end

  it "fetches the metadata at most every twelve hours" do
    publish(bund_id_metadata)
    BundIdServices::IdpCertificates.call(idp_url)

    travel(11.hours) { BundIdServices::IdpCertificates.call(idp_url) }
    travel(13.hours) { BundIdServices::IdpCertificates.call(idp_url) }

    expect(Net::HTTP).to have_received(:start).twice
  end

  it "falls back to the last known certificates while BundID's metadata is unavailable" do
    publish(bund_id_metadata)
    BundIdServices::IdpCertificates.call(idp_url)
    bundid_down

    travel(13.hours) do
      expect(BundIdServices::IdpCertificates.call(idp_url)).to eq([bund_id_certificate(:bund_id)])
    end
  end

  it "is unavailable when BundID's metadata could never be read" do
    bundid_down

    expect { BundIdServices::IdpCertificates.call(idp_url) }
      .to raise_error(BundIdServices::IdpCertificates::Unavailable)
  end

  it "is unavailable when the metadata belongs to a different identity provider" do
    publish(bund_id_metadata(entity_id: "https://other-idp.test"))

    expect { BundIdServices::IdpCertificates.call(idp_url) }
      .to raise_error(BundIdServices::IdpCertificates::Unavailable)
  end

  it "refuses to read the metadata over plain http" do
    allow(Net::HTTP).to receive(:start)

    expect { BundIdServices::IdpCertificates.call("http://idp.bund-id.test") }
      .to raise_error(BundIdServices::IdpCertificates::Unavailable)
    expect(Net::HTTP).not_to have_received(:start)
  end
end
