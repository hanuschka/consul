require "rails_helper"

describe "Requesting an image variant signed with legacy combine_options", type: :request do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/clippy.jpg").open,
      filename: "clippy.jpg",
      content_type: "image/jpeg"
    )
  end

  let(:unsupported_method_error) do
    ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod
  end

  it "processes the variant instead of returning a 500" do
    legacy_transformations = {
      combine_options: { gravity: "center", resize: "300x300^", crop: "300x300+0+0" }
    }
    legacy_variant = blob.variant(legacy_transformations)

    get rails_representation_url(legacy_variant, only_path: true)

    expect(response).to have_http_status(:found)
    expect(legacy_variant.processed.image).to be_attached
  end

  it "still rejects unsupported operations outside combine_options" do
    unsafe_variant = blob.variant(system: "dangerous_command")

    expect { unsafe_variant.processed }.to raise_error(unsupported_method_error)
  end

  it "still rejects unsupported operations unwrapped from combine_options" do
    unsafe_variant = blob.variant(combine_options: { system: "dangerous_command" })

    expect { unsafe_variant.processed }.to raise_error(unsupported_method_error)
  end
end
