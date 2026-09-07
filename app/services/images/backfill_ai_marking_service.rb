class Images::BackfillAiMarkingService < ApplicationService
  # Writes the IPTC marker into pictures this app generated but attached
  # unmarked. The WhatsApp bot's generation route went through the plain attach
  # service, so its pictures published with neither the marker in the file nor
  # ai_generated on the record, while the same generation from the web editor
  # carried both. The route is fixed; these are the records that went out first.
  #
  # The marker rather than only the flag: the flag puts the disclosure label on
  # the page, and the marker is what a verification tool outside this portal
  # reads. A picture the app generated must carry both, so the bytes are marked
  # and re-attached rather than the flag set over an unmarked file.
  #
  # Only pictures on a resource that records having been generated here. A photo
  # a citizen uploaded and declared AI-made is not one of these: its bytes are
  # theirs, and the in-app flag the marking sets is what exempts a file from the
  # EXIF strip, so claiming it over an upload would publish their camera GPS.
  #
  # A run reports what it did and never raises: an image whose marking fails
  # keeps the state it already had, and the count says how many are still
  # waiting. Re-running is how they are picked up once exiftool is available.
  RESOURCE_CLASSES = [Proposal, Budget::Investment].freeze

  Report = Struct.new(:marked, :already_marked, :failed, :skipped, keyword_init: true)

  def initialize(logger: Rails.logger)
    @logger = logger
    @report = Report.new(marked: 0, already_marked: 0, failed: 0, skipped: 0)
  end

  def call
    unmarked_images.find_each { |image| process(image) }

    @report
  end

  private

    # Scoped by the resource's own column rather than by the image's flags,
    # because the flags are exactly what the broken route failed to write: an
    # image with ai_generated false is indistinguishable from an upload from
    # here, and the resource is the only place the origin was recorded.
    def unmarked_images
      resource_conditions = RESOURCE_CLASSES.map do |resource_class|
        Image
          .where(imageable_type: resource_class.name)
          .where(imageable_id: resource_class.unscoped.where(generated_image: true).select(:id))
      end

      resource_conditions.reduce { |scope, condition| scope.or(condition) }.with_attached_attachment
    end

    def process(image)
      return skip(image, "no attachment") if !image.attachment.attached?

      bytes = image.attachment.download

      return already_marked(image) if marker_in?(bytes, image)

      mark_and_reattach(image, bytes)
    rescue ::Images::MarkAiGeneratedService::MarkingFailedError => e
      fail_image(image, e.reason)
    rescue StandardError => e
      fail_image(image, "#{e.class}: #{e.message}")
    end

    # In the order from_generated_base64 uses, and for its reasons: the marking
    # service stages ai_generated_in_app onto the record, both flags are
    # declarations that count for the save they are made in, and the attachment
    # and the flags therefore have to reach the database in one save.
    def mark_and_reattach(image, bytes)
      filename = image.attachment.filename.to_s
      content_type = image.attachment.content_type.presence || "image/jpeg"

      marking = ::Images::MarkAiGeneratedService.call(
        image: image,
        data: bytes,
        filename: filename,
        content_type: content_type,
        ai_system: ::DtApi::Resources::Ai::PROVIDER_NAME
      )

      image.attachment = uploaded_file(
        marking.data[:image_data], filename: filename, content_type: content_type
      )
      image.ai_generated = true
      image.save!

      @report.marked += 1

      @logger.info("[Images::BackfillAiMarkingService] marked image #{image.id}")
    end

    def uploaded_file(data, filename:, content_type:)
      file = Tempfile.new(["ai_marking_backfill", File.extname(filename)], binmode: true)
      file.write(data)
      file.rewind

      ActionDispatch::Http::UploadedFile.new(
        tempfile: file, filename: filename, type: content_type
      )
    end

    # The bytes are the authority on whether a picture is already marked, not the
    # flags: a record can carry ai_generated over a file that was never marked,
    # which is the state this backfill exists to end.
    def marker_in?(bytes, image)
      file = Tempfile.new(["ai_marking_check", File.extname(image.attachment.filename.to_s)],
                          binmode: true)

      begin
        file.write(bytes)
        file.flush

        ::ExiftoolCommand.read_tag(
          file.path, ::Images::MarkAiGeneratedService::DIGITAL_SOURCE_TYPE_TAG
        ) == ::Images::MarkAiGeneratedService::TRAINED_ALGORITHMIC_MEDIA
      ensure
        file.close
        file.unlink
      end
    end

    # A file that already carries the marker still needs the flags, which is the
    # state a partly-completed earlier run leaves behind.
    def already_marked(image)
      @report.already_marked += 1

      return if image.ai_generated? && image.ai_generated_in_app?

      image.ai_generated = true
      image.ai_generated_in_app = true
      image.save!
    end

    def skip(image, reason)
      @report.skipped += 1

      @logger.info("[Images::BackfillAiMarkingService] skipped image #{image.id}: #{reason}")
    end

    def fail_image(image, reason)
      @report.failed += 1

      @logger.error("[Images::BackfillAiMarkingService] image #{image.id} failed: #{reason}")
    end
end
