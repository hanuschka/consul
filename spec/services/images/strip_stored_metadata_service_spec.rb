require "rails_helper"

describe Images::StripStoredMetadataService do
  def unstripped_blob(file, filename: "photo.jpg")
    ActiveStorage::Blob.create_and_upload!(io: file, filename: filename, content_type: "image/jpeg")
  end

  def attach_without_stripping(blob, **attributes)
    image = Image.new(**attributes)
    image.save!(validate: false)
    ActiveStorage::Attachment.create!(record: image, name: "attachment", blob: blob)
    image
  end

  it "strips images that were stored before the upload strip existed" do
    blob = unstripped_blob(gps_jpeg)
    attach_without_stripping(blob)

    report = Images::StripStoredMetadataService.call

    expect(report.stripped).to eq 1
    expect(stored_tags(blob.reload).keys).not_to include("GPS:GPSLatitude", "IFD0:Make")
    expect(blob.metadata["metadata_stripped"]).to be true
  end

  it "strips a stored JPEG whose filename says otherwise" do
    blob = unstripped_blob(gps_jpeg, filename: "IMG_0001.HEIC")
    attach_without_stripping(blob)

    expect(Images::StripStoredMetadataService.call.stripped).to eq 1
    expect(stored_tags(blob.reload).keys).not_to include("GPS:GPSLatitude")
  end

  it "replaces the stored file under the same key" do
    blob = unstripped_blob(gps_jpeg)
    attach_without_stripping(blob)
    key = blob.key

    Images::StripStoredMetadataService.call

    expect(blob.reload.key).to eq key
    expect(blob.checksum).to eq Digest::MD5.base64digest(blob.download)
    expect(Dir.glob("#{blob.service.path_for(key)}.*")).to be_empty
  end

  it "leaves the stored file intact when it cannot be replaced" do
    blob = unstripped_blob(gps_jpeg)
    attach_without_stripping(blob)
    allow(File).to receive(:rename).and_raise(Errno::EACCES)
    allow(Sentry).to receive(:capture_exception) if defined?(Sentry)

    expect(Images::StripStoredMetadataService.call.failed).to eq 1
    expect(blob.reload.checksum).to eq Digest::MD5.base64digest(blob.download)
    expect(stored_tags(blob).keys).to include("GPS:GPSLatitude")
    expect(Dir.glob("#{blob.service.path_for(blob.key)}.*")).to be_empty
  end

  it "lets a signal through only once the blob it arrived during is done" do
    stub_const("Images::StripStoredMetadataService::DEFERRED_SIGNALS", %w[USR2])
    blob = unstripped_blob(gps_jpeg)
    attach_without_stripping(blob)
    allow(File).to receive(:rename).and_wrap_original do |rename, *args|
      rename.call(*args)
      Process.kill("USR2", Process.pid)
    end
    previous = Signal.trap("USR2") { raise Interrupt }

    expect { Images::StripStoredMetadataService.call }.to raise_error(Interrupt)
    expect(blob.reload.checksum).to eq Digest::MD5.base64digest(blob.download)
    expect(blob.metadata["metadata_stripped"]).to be true
  ensure
    Signal.trap("USR2", previous || "DEFAULT")
  end

  it "keeps the AI marker on images generated in the app" do
    blob = unstripped_blob(ai_marked_jpeg)
    attach_without_stripping(blob, ai_generated: true, ai_generated_in_app: true)

    report = Images::StripStoredMetadataService.call

    expect(report.exempt).to eq 1
    expect(ai_marker_stored?(blob.reload)).to be true
    expect(stored_tags(blob).keys).not_to include("GPS:GPSLatitude", "IFD0:Make")
  end

  it "skips blobs it has already stripped" do
    attach_without_stripping(unstripped_blob(gps_jpeg))
    Images::StripStoredMetadataService.call

    expect(Images::StripStoredMetadataService.call.already_stripped).to eq 1
  end

  it "counts a blob whose file is missing as failed and carries on" do
    missing = unstripped_blob(gps_jpeg)
    missing.service.delete(missing.key)
    attach_without_stripping(unstripped_blob(gps_jpeg))

    report = Images::StripStoredMetadataService.call

    expect(report.failed).to eq 1
    expect(report.stripped).to eq 1
  end

  it "refuses to run when exiftool cannot run" do
    attach_without_stripping(unstripped_blob(gps_jpeg))
    allow(ExiftoolCommand).to receive(:version).and_return(nil)

    expect { Images::StripStoredMetadataService.call }
      .to raise_error(Images::StripStoredMetadataService::ExiftoolUnavailableError)
  end

  it "reports its progress" do
    stub_const("Images::StripStoredMetadataService::PROGRESS_EVERY", 1)
    2.times { attach_without_stripping(unstripped_blob(gps_jpeg)) }
    progress = []

    Images::StripStoredMetadataService.call do |report, done, total|
      progress << [done, total, report.stripped]
    end

    expect(progress).to eq [[1, 2, 1], [2, 2, 2]]
  end
end
