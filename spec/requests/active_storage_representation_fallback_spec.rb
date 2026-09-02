require "rails_helper"

describe "Requesting an image variant when ImageMagick fails", type: :request do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/clippy.png").open,
      filename: "clippy.png",
      content_type: "image/png"
    )
  end

  let(:variation) { ActiveStorage::Variation.new(resize_to_limit: [300, 180]) }

  def get_representation
    get rails_representation_url(
      blob.variant(variation.transformations),
      only_path: true
    )
  end

  context "when the conversion blows ImageMagick's resource limits" do
    before do
      allow_any_instance_of(ActiveStorage::Variation)
        .to receive(:transform)
        .and_raise(MiniMagick::Error, "cache resources exhausted")
    end

    it "serves the original blob instead of returning a 500" do
      get_representation

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to include("clippy.png")
      expect(response.headers["Location"]).not_to include("representations")
    end

    it "still reports the failure so the server limit stays visible" do
      expect(Sentry).to receive(:capture_exception)
        .with(instance_of(MiniMagick::Error), hash_including(level: :warning))

      get_representation
    end
  end

  context "when the image is unusable" do
    before do
      allow_any_instance_of(ActiveStorage::Variation)
        .to receive(:transform)
        .and_raise(MiniMagick::Invalid, "not an image")
    end

    it "falls back rather than raising" do
      get_representation

      expect(response).to have_http_status(:found)
    end
  end

  context "when the conversion succeeds" do
    it "serves the variant without reporting anything" do
      expect(Sentry).not_to receive(:capture_exception)

      get_representation

      expect(response).to have_http_status(:found)
    end
  end
end
