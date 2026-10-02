require "rails_helper"

describe ImageMetadataStripper do
  let(:personal_tags) do
    %w[GPS:GPSLatitude GPS:GPSLongitude IFD0:Make IFD0:Model ExifIFD:DateTimeOriginal]
  end

  def save_image(file, filename: "photo.jpg", **attributes)
    image = Image.new(attachment: uploaded(file, filename: filename), **attributes)
    image.save!(validate: false)
    image.reload
  end

  def stored_blob(file)
    ActiveStorage::Blob.create_and_upload!(io: file, filename: "photo.jpg", content_type: "image/jpeg")
  end

  describe "uploading an image" do
    it "removes the camera metadata from the stored original" do
      image = save_image(gps_jpeg)
      tags = stored_tags(image.attachment.blob)

      expect(tags.keys & personal_tags).to be_empty
      expect(tags["IFD0:Orientation"]).to eq 6
      expect(image.attachment.blob.metadata["metadata_stripped"]).to be true
    end

    it "keeps the dimensions" do
      original = gps_jpeg
      image = save_image(original)

      expect(stored_dimensions(image.attachment.blob)).to eq MiniMagick::Image.open(original.path).dimensions
    end

    it "keeps the checksum and size in line with the stored file" do
      blob = save_image(gps_jpeg).attachment.blob

      expect(blob.byte_size).to eq blob.download.bytesize
      expect(blob.checksum).to eq Digest::MD5.base64digest(blob.download)
    end

    it "strips through the direct upload path, before the form is submitted" do
      image = Image.new(attachment: uploaded(gps_jpeg))
      image.attachment.blob.save!
      image.attachment_changes["attachment"].upload

      expect(stored_tags(image.attachment.blob.reload).keys & personal_tags).to be_empty
    end

    it "strips images attached to other records" do
      user = create(:user)
      user.background_image.attach(io: gps_jpeg, filename: "photo.jpg", content_type: "image/jpeg")

      expect(stored_tags(user.reload.background_image.blob).keys & personal_tags).to be_empty
    end

    it "strips a previously stored blob when it is attached" do
      blob = stored_blob(gps_jpeg)
      image = Image.new(attachment: blob.signed_id)
      image.save!(validate: false)

      expect(stored_tags(blob.reload).keys & personal_tags).to be_empty
    end

    %w[photo.png IMG_0001.HEIC].each do |filename|
      it "strips a JPEG named #{filename}" do
        image = save_image(gps_jpeg, filename: filename)

        expect(stored_tags(image.attachment.blob).keys & personal_tags).to be_empty
      end
    end
  end

  describe "a save that is rolled back" do
    it "leaves a stored blob untouched until the save succeeds" do
      proposal = create(:proposal)
      blob = stored_blob(gps_jpeg)
      image = Image.new(imageable: proposal, user: proposal.author, title: "x", attachment: blob.signed_id)

      expect(image.save).to be false
      expect(blob.reload.checksum).to eq Digest::MD5.base64digest(blob.download)

      image.update!(title: "photo")

      expect(stored_tags(blob.reload).keys & personal_tags).to be_empty
      expect(blob.checksum).to eq Digest::MD5.base64digest(blob.download)
    end
  end

  describe "images generated in the app" do
    it "keeps the AI marker" do
      image = save_image(ai_marked_jpeg, ai_generated: true)

      expect(image.ai_generated_in_app).to be true
      expect(ai_marker_stored?(image.attachment.blob)).to be true
      expect(stored_tags(image.attachment.blob).keys & personal_tags).to be_empty
    end

    it "keeps the AI marker on a direct upload" do
      image = Image.new(attachment: uploaded(ai_marked_jpeg))
      image.attachment.blob.save!
      image.attachment_changes["attachment"].upload

      expect(ai_marker_stored?(image.attachment.blob)).to be true
      expect(stored_tags(image.attachment.blob).keys & personal_tags).to be_empty
    end

    it "keeps the AI marker when a stored image is replaced with a declared AI file" do
      proposal = create(:proposal)
      image = Image.create!(
        imageable: proposal, user: proposal.author, title: "photo", attachment: uploaded(gps_jpeg)
      )

      image.reload.update!(attachment: uploaded(ai_marked_jpeg), ai_generated: true)
      blob = image.reload.attachment.blob

      expect(image.ai_generated_in_app).to be true
      expect(ai_marker_stored?(blob)).to be true
      expect(stored_tags(blob).keys & personal_tags).to be_empty
      expect(blob.checksum).to eq Digest::MD5.base64digest(blob.download)
      expect(blob.metadata["metadata_stripped"]).to be_nil
    end

    it "keeps the AI marker when attached through an io" do
      image = Image.new(ai_generated_in_app: true)
      image.attachment = { io: StringIO.new(File.binread(ai_marked_jpeg.path)),
                           filename: "ai.jpg", content_type: "image/jpeg" }
      image.save!(validate: false)

      expect(ai_marker_stored?(image.reload.attachment.blob)).to be true
      expect(stored_tags(image.attachment.blob).keys & personal_tags).to be_empty
    end

    it "strips the marker when the upload is not declared as AI-generated" do
      image = save_image(ai_marked_jpeg)

      expect(image.ai_generated_in_app).to be false
      expect(ai_marker_stored?(image.attachment.blob)).to be false
    end
  end

  describe "a failing strip" do
    it "still stores the upload and reports it" do
      allow(ExiftoolCommand).to receive(:strip_metadata).and_return(
        GuardedCommand::Result.new(stdout: "", stderr: "boom", timed_out: false, exit_status: 1)
      )
      allow(Sentry).to receive(:capture_exception) if defined?(Sentry)

      image = save_image(gps_jpeg)

      blob = image.attachment.blob

      expect(blob.checksum).to eq Digest::MD5.base64digest(blob.download)
      expect(blob.metadata["metadata_stripped"]).to be_nil
    end

    it "keeps the attached blob in line with its stored file when the file cannot be replaced" do
      blob = stored_blob(gps_jpeg)
      allow(File).to receive(:rename).and_raise(Errno::EACCES)
      allow(Sentry).to receive(:capture_exception) if defined?(Sentry)

      image = Image.new(attachment: blob.signed_id)
      image.save!(validate: false)
      attached = image.attachment.blob

      expect(attached.checksum).to eq blob.reload.checksum
      expect(attached.checksum).to eq Digest::MD5.base64digest(attached.download)
    end

    it "does not break attaching a stored blob" do
      blob = stored_blob(gps_jpeg)
      allow(ImageMetadataStripper).to receive(:strip_stored!).and_raise(ActiveStorage::IntegrityError)
      allow(Sentry).to receive(:capture_exception) if defined?(Sentry)

      image = Image.new(attachment: blob.signed_id)

      expect { image.save!(validate: false) }.not_to raise_error
      expect(image.reload.attachment.blob).to eq blob
    end
  end
end
