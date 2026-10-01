module ImageMetadataHelpers
  def tagged_jpeg(*tags)
    file = Tempfile.new(["tagged", ".jpg"], binmode: true)
    IO.copy_stream(Rails.root.join("spec/fixtures/files/clippy.jpg").to_s, file)
    file.flush
    ExiftoolCommand.run("-q", "-overwrite_original", *tags, file.path)
    file.open
    file
  end

  def camera_tags
    [
      "-GPSLatitude=48.137", "-GPSLatitudeRef=N", "-GPSLongitude=11.575", "-GPSLongitudeRef=E",
      "-Make=Apple", "-Model=iPhone 15", "-DateTimeOriginal=2026:01:01 10:00:00"
    ]
  end

  def gps_jpeg
    tagged_jpeg(*camera_tags, "-Orientation#=6")
  end

  def ai_marked_jpeg
    tagged_jpeg(
      *camera_tags,
      "-#{Images::MarkAiGeneratedService::DIGITAL_SOURCE_TYPE_TAG}=" \
      "#{Images::MarkAiGeneratedService::TRAINED_ALGORITHMIC_MEDIA}"
    )
  end

  def uploaded(file, filename: "photo.jpg")
    ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: filename, type: "image/jpeg")
  end

  def stored_tags(blob)
    blob.open do |file|
      result = ExiftoolCommand.run("-j", "-a", "-G1", "-n", file.path)
      JSON.parse(result.stdout).first.reject { |key, _| key.start_with?("System:", "ExifTool:", "File:") }
    end
  end

  def stored_dimensions(blob)
    blob.open { |file| MiniMagick::Image.open(file.path).dimensions }
  end

  def ai_marker_stored?(blob)
    Images::AiMarker.marker_in?(blob.download)
  end
end

RSpec.configure do |config|
  config.include ImageMetadataHelpers
end
