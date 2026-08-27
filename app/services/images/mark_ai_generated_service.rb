# Marks a generated image as machine-readable AI output before it is attached.
#
# The marker is written before the bytes are attached, since every delivered
# rendering is resized from the attached copy and the marker has to be in place
# before that happens.
#
# The generator's own signed provenance manifest is removed rather than left in
# place: our marker changes the bytes that manifest hashes over, and a
# verification tool reading a broken signature reports the picture as tampered
# with, which is worse than reporting no manifest at all.
#
# Marking is mandatory. An image that cannot be marked is not attached at all:
# publishing an unmarked generated picture is the thing the mark exists to
# prevent, so the failure is raised for the caller to surface rather than
# absorbed into a quietly unmarked image.
class Images::MarkAiGeneratedService < ApplicationService
  class MarkingFailedError < StandardError
    attr_reader :reason

    def initialize(message, reason:)
      @reason = reason

      super(message)
    end
  end

  # The IPTC vocabulary term for content produced by a generative model, and
  # the field public verification tools read. It is the same value the
  # generator's own signed manifest carries internally, so the delivered copy
  # states what the original states, in a form that survives being resized.
  DIGITAL_SOURCE_TYPE_TAG = "XMP-iptcExt:DigitalSourceType".freeze
  TRAINED_ALGORITHMIC_MEDIA =
    "http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia".freeze

  # Named the generating system rather than only the fact of generation: the
  # source type answers "was this generated", these answer "by what", which is
  # the next question every reader of the first answer has. Both are omitted
  # when the generator does not report a model, so the file never claims a
  # system it cannot name.
  AI_SYSTEM_TAG = "XMP-iptcExt:AISystemUsed".freeze
  AI_SYSTEM_VERSION_TAG = "XMP-iptcExt:AISystemVersionUsed".freeze

  def initialize(image:, data:, filename:, content_type:, ai_system: nil, ai_system_version: nil)
    @image = image
    @data = data
    @filename = filename
    @content_type = content_type
    @ai_system = ai_system
    @ai_system_version = ai_system_version
  end

  def call
    ensure_runtime_available

    marked_data = mark

    if marked_data.blank?
      raise MarkingFailedError.new(
        "marking failed for #{@filename}",
        reason: :marking_failed
      )
    end

    # Recorded on the record rather than derived later: this is what exempts
    # the picture from the EXIF strip every other variant gets, and so keeps
    # the marker in the renderings that are actually delivered.
    @image.ai_generated_in_app = true

    ::ServiceResult.success(image_data: marked_data, marked: true)
  rescue MarkingFailedError => e
    Rails.logger.error("[Images::MarkAiGeneratedService] #{e.reason}: #{e.message}")

    if defined?(Sentry)
      Sentry.capture_exception(e, level: :error, extra: { reason: e.reason })
    end

    raise
  end

  private

    def ensure_runtime_available
      status = ::ExiftoolCommand.runtime_status

      return if status == ::ExiftoolCommand::READY

      raise MarkingFailedError.new("marking runtime unavailable (#{status})", reason: status)
    end

    def marking_arguments
      arguments = [
        "-overwrite_original",
        "-jumbf:all=",
        "-#{DIGITAL_SOURCE_TYPE_TAG}=#{TRAINED_ALGORITHMIC_MEDIA}"
      ]

      arguments << "-#{AI_SYSTEM_TAG}=#{@ai_system}" if @ai_system.present?
      arguments << "-#{AI_SYSTEM_VERSION_TAG}=#{@ai_system_version}" if @ai_system_version.present?

      arguments
    end

    def mark
      file = Tempfile.new(["ai_marking", File.extname(@filename)], binmode: true)

      begin
        file.write(@data)
        file.flush

        result = ::ExiftoolCommand.run(*marking_arguments, file.path)

        if !result.success?
          Rails.logger.warn(
            "[Images::MarkAiGeneratedService] exiftool #{result.failure_reason}: " \
            "#{result.stderr.to_s.strip.truncate(200)}"
          )

          return nil
        end

        # Read back before reporting success: a marker that did not survive the
        # write is indistinguishable from an unmarked image to every later
        # reader, and the caller must be able to tell the difference now.
        written = ::ExiftoolCommand.read_tag(file.path, DIGITAL_SOURCE_TYPE_TAG)

        return nil if written != TRAINED_ALGORITHMIC_MEDIA

        File.binread(file.path)
      ensure
        file.close
        file.unlink
      end
    end
end
