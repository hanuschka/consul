# Marks a generated image as machine-readable AI output before it is attached.
#
# Two things happen here, and the order matters. The generator's own bytes are
# kept verbatim as a second attachment, because they carry the signed
# provenance manifest the image service produced and watermarking re-encodes
# the file, which destroys it. Only then is the watermark embedded, since every
# delivered rendering is resized from the attached copy and the mark has to be
# in place before that happens.
#
# Marking is mandatory. An image that cannot be marked is not attached at all:
# publishing an unmarked generated picture is the thing the mark exists to
# prevent, so the failure is raised for the caller to surface rather than
# absorbed into a quietly unmarked image.
class Images::EmbedAiWatermarkService < ApplicationService
  class MarkingFailedError < StandardError
    attr_reader :reason

    def initialize(message, reason:)
      @reason = reason

      super(message)
    end
  end

  SOURCE_ATTACHMENT_PREFIX = "source".freeze

  def initialize(image:, data:, filename:, content_type:)
    @image = image
    @data = data
    @filename = filename
    @content_type = content_type
  end

  def call
    ensure_runtime_available

    identifier = ::TrustmarkCommand.generate_identifier
    watermarked_data = embed(identifier)

    if watermarked_data.blank?
      raise MarkingFailedError.new(
        "watermark embedding failed for #{@filename}",
        reason: :embedding_failed
      )
    end

    attach_source_copy
    @image.watermark_identifier = identifier

    ::ServiceResult.success(
      image_data: watermarked_data,
      watermarked: true,
      identifier: identifier
    )
  rescue MarkingFailedError => e
    Rails.logger.error("[Images::EmbedAiWatermarkService] #{e.reason}: #{e.message}")

    if defined?(Sentry)
      Sentry.capture_exception(e, level: :error, extra: { reason: e.reason })
    end

    raise
  end

  private

    def ensure_runtime_available
      status = ::TrustmarkCommand.runtime_status

      return if status == ::TrustmarkCommand::READY

      raise MarkingFailedError.new(
        runtime_failure_message(status),
        reason: status
      )
    end

    def runtime_failure_message(status)
      if status == ::TrustmarkCommand::LIBRARIES_MISSING
        return "watermarking runtime is missing python packages: #{::TrustmarkCommand.missing_libraries}"
      end

      "watermarking runtime unavailable (#{status})"
    end

    def embed(identifier)
      source_file = Tempfile.new(["watermark_source", File.extname(@filename)], binmode: true)
      marked_file = Tempfile.new(["watermark_marked", File.extname(@filename)], binmode: true)

      begin
        source_file.write(@data)
        source_file.flush

        embedded = ::TrustmarkCommand.embed(source_file.path, marked_file.path, identifier)

        return nil if !embedded

        File.binread(marked_file.path)
      ensure
        [source_file, marked_file].each do |file|
          file.close
          file.unlink
        end
      end
    end

    # Staged on an unsaved record too: ActiveStorage persists it with the record
    # the caller is about to save.
    def attach_source_copy
      @image.source_attachment.attach(
        io: StringIO.new(@data),
        filename: "#{SOURCE_ATTACHMENT_PREFIX}_#{@filename}",
        content_type: @content_type
      )
    end
end
