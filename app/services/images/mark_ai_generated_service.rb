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

  # The same fact in prose, in the one field every picture viewer shows under
  # "Description". It documents the file for a person opening its properties;
  # verification tools key on the source type above, so this line is never what
  # marking succeeds or fails on. English, because the field has no language.
  IMAGE_DESCRIPTION_TAG = "EXIF:ImageDescription".freeze
  AI_DESCRIPTION = "AI-generated image.".freeze

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

    # Only what the running exiftool can actually write is asked for. A tag it
    # does not define, or a group it cannot delete, is a warning that still
    # exits 0 -- so sending one would leave the read-back below unable to tell
    # a refused write from a binary that never supported the tag.
    def marking_arguments
      arguments = ["-overwrite_original"]

      arguments << "-jumbf:all=" if ::ExiftoolCommand.supports_jumbf_delete?

      written_tags.each { |tag, value| arguments << "-#{tag}=#{value}" }

      # Outside written_tags on purpose: the prose line is documentation for a
      # person opening the file's properties, and no verification tool keys on
      # it, so it is never what the read-back below fails marking over.
      arguments << "-#{IMAGE_DESCRIPTION_TAG}=#{AI_DESCRIPTION}"

      arguments
    end

    # The tags this run asks for, and the value each one has to read back as.
    def written_tags
      @written_tags ||= begin
        tags = { DIGITAL_SOURCE_TYPE_TAG => TRAINED_ALGORITHMIC_MEDIA }

        if ::ExiftoolCommand.supports_ai_system_tags?
          tags[AI_SYSTEM_TAG] = @ai_system if @ai_system.present?
          tags[AI_SYSTEM_VERSION_TAG] = @ai_system_version if @ai_system_version.present?
        end

        tags
      end
    end

    # The first tag that did not survive the write, or nil when all of them
    # did. Every asked-for tag is checked rather than only the source type: a
    # tag exiftool refuses is reported as a warning next to a successful write
    # of the others, so the exit status says nothing about any single one.
    def unwritten_tag(path)
      written_tags.find do |tag, value|
        ::ExiftoolCommand.read_tag(path, tag) != value
      end
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
        missing_tag, = unwritten_tag(file.path)

        if missing_tag.present?
          Rails.logger.warn(
            "[Images::MarkAiGeneratedService] #{missing_tag} did not survive the write"
          )

          return nil
        end

        File.binread(file.path)
      ensure
        file.close
        file.unlink
      end
    end
end
