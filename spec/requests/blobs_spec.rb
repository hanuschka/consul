require "rails_helper"

describe "Stored files served by BlobsController", type: :request do
  let(:picture) { create(:admin_image) }
  let(:key) { picture.storage_data.blob.key }

  def image_sources_in(email)
    html = email.html_part&.decoded || email.body.decoded

    Nokogiri::HTML(html).css("img").map { |img| img["src"] }
  end

  def upload_blob(filename)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(file_fixture("clippy.jpg").binread),
      filename: filename,
      content_type: "image/jpeg"
    )
  end

  context "on an instance behind HTTP basic auth" do
    before do
      allow(Rails.application.secrets).to receive(:http_basic_auth).and_return(true)
      allow(Rails.application.secrets).to receive(:http_basic_username).and_return("staging")
      allow(Rails.application.secrets).to receive(:http_basic_password).and_return("secret")
      set_setting("url", "https://city.example")
    end

    it "lets a mail client load a newsletter block image without credentials" do
      newsletter = create(:newsletter)
      create(:site_customization_content_block,
             newsletter: newsletter,
             body: %(<p><img src="/blobs/#{key}/variant?w=1200&amp;h=1000" alt="Image"></p>))

      email = Mailer.newsletter(newsletter, "reader@example.org")
      src = image_sources_in(email).find { |source| source.include?("/blobs/#{key}") }

      expect(src).to start_with("https://city.example/blobs/#{key}/variant")

      get URI.parse(src).request_uri

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to start_with("image/")
    end

    it "serves a public file without credentials and without a session cookie" do
      get blob_asset_path(key)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Set-Cookie"]).to be_blank
    end

    it "serves the legacy ckeditor asset path without credentials" do
      get "/ckeditor/assets/#{key}"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to start_with("image/")
    end

    it "still protects ordinary pages" do
      get root_path

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "access rules", :show_exceptions do
    it "refuses a file that is not attached to any record" do
      blob = upload_blob("unattached.jpg")

      get blob_asset_path(blob.key)

      expect(response).to have_http_status(:not_found)
    end

    it "refuses a file attached to a record type that is not public" do
      blob = upload_blob("internal.jpg")
      ActiveStorage::Attachment.create!(name: "internal_file", record: create(:newsletter), blob: blob)

      get blob_asset_path(blob.key)

      expect(response).to have_http_status(:not_found)
    end

    it "answers 404 instead of 500 when the variant size is not a number" do
      get blob_variant_path(key, w: ["1200"], h: 1000)

      expect(response).to have_http_status(:not_found)
    end

    it "answers 404 for a variant size outside the allowed list" do
      get blob_variant_path(key, w: 20_000, h: 20_000)

      expect(response).to have_http_status(:not_found)
    end
  end
end
