module ImageMetadataStripper
  CONTENT_TYPES = %w[
    image/jpeg image/jpg image/pjpeg image/png image/webp image/gif image/avif image/heic image/heif
  ].freeze

  FLAG = "metadata_stripped".freeze

  INTERNAL_RECORD_TYPES = %w[ActiveStorage::VariantRecord ActiveStorage::Blob].freeze

  class StripFailedError < StandardError; end

  def self.strippable?(blob)
    CONTENT_TYPES.include?(blob.content_type.to_s)
  end

  def self.stripped?(blob)
    blob.metadata[FLAG] == true
  end

  def self.internal_record?(record)
    INTERNAL_RECORD_TYPES.include?(record.class.name)
  end

  def self.exempt_blob?(blob)
    source_blob_ids = ::ActiveStorage::VariantRecord
      .joins(:image_attachment)
      .where(active_storage_attachments: { blob_id: blob.id })
      .pluck(:blob_id)

    ::Image
      .where(ai_generated_in_app: true)
      .joins(:attachment_attachment)
      .where(active_storage_attachments: { blob_id: [blob.id, *source_blob_ids] })
      .exists?
  end

  def self.copy_to_tempfile(io)
    file = Tempfile.new("metadata_strip", binmode: true)
    io.rewind if io.respond_to?(:rewind)
    IO.copy_stream(io, file)
    file.flush
    file
  end

  def self.ai_marker_tags
    [
      ::Images::MarkAiGeneratedService::DIGITAL_SOURCE_TYPE_TAG,
      ::Images::MarkAiGeneratedService::AI_SYSTEM_TAG,
      ::Images::MarkAiGeneratedService::AI_SYSTEM_VERSION_TAG,
      ::Images::MarkAiGeneratedService::IMAGE_DESCRIPTION_TAG
    ]
  end

  def self.strip_file!(path, keep_ai_marker: false)
    result = ::ExiftoolCommand.strip_metadata(path, keep: keep_ai_marker ? ai_marker_tags : [])

    raise StripFailedError, "exiftool #{result.failure_reason}: #{result.stderr}" if !result.success?
  end

  def self.upload_stripped(blob, path, keep_ai_marker: false)
    strip_file!(path, keep_ai_marker: keep_ai_marker)
    upload_file(blob, path, stripped: !keep_ai_marker)
  end

  def self.upload_file(blob, path, stripped: false)
    File.open(path, "rb") do |file|
      blob.unfurl(file, identify: false)
      blob.metadata = stripped ? blob.metadata.merge(FLAG => true) : blob.metadata.except(FLAG)
      blob.upload_without_unfurling(file)
    end

    blob.save! if blob.persisted?
  end

  def self.strip_stored!(blob, keep_ai_marker: false)
    blob.service.open(blob.key, checksum: blob.checksum) do |file|
      strip_file!(file.path, keep_ai_marker: keep_ai_marker)
      replace_stored_file(blob, file.path, stripped: !keep_ai_marker)
    end
  end

  def self.replace_stored_file(blob, path, stripped: true)
    previous = blob.attributes.slice("checksum", "byte_size", "metadata").deep_dup

    File.open(path, "rb") { |file| blob.unfurl(file, identify: false) }
    blob.metadata = stripped ? blob.metadata.merge(FLAG => true) : blob.metadata.except(FLAG)

    blob.transaction do
      file_changed = blob.checksum_changed?
      blob.save!
      write_stored_file(blob, path) if file_changed
    end
  rescue StandardError
    blob.assign_attributes(previous)
    raise
  end

  def self.write_stored_file(blob, path)
    if disk_service?(blob.service)
      rename_into_place(path, blob.service.path_for(blob.key))
    else
      File.open(path, "rb") { |file| blob.upload_without_unfurling(file) }
    end
  end

  def self.rename_into_place(path, target)
    staged = "#{target}.#{SecureRandom.hex(8)}.tmp"

    File.open(staged, "wb") do |out|
      IO.copy_stream(path, out)
      out.fsync
    end

    File.rename(staged, target)
  ensure
    FileUtils.rm_f(staged) if staged
  end

  def self.disk_service?(service)
    defined?(::ActiveStorage::Service::DiskService) && service.is_a?(::ActiveStorage::Service::DiskService)
  end

  def self.report_failure(blob, error)
    Rails.logger.error("[ImageMetadataStripper] blob #{blob.id.inspect} kept its metadata: #{error.message}")
    Sentry.capture_exception(error, extra: { blob_id: blob.id }) if defined?(Sentry)
  end
end
