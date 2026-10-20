class Whatsapp::Drafting::UploadDraftImageService < ApplicationService
  # The draft's picture, handed to WhatsApp so the preview renders from its own
  # media rather than from a link back to us. Before anything is published the
  # only copy lives on a draft record behind whatever access rules the
  # environment has — on a closed staging box Meta cannot fetch it at all, and
  # WhatsApp refuses the whole message over a header it could not load.
  #
  # Returns the media id, or nil when there is no usable picture. Nil is the
  # caller's cue to send the same message without one; every caller has that
  # shape already, because the URL route could fail the same way.
  def initialize(resource:)
    @resource = resource
  end

  # Every nil says why. The caller degrades quietly by design, so a preview that
  # arrives without its picture looks the same whether the draft never had one,
  # the file was of a kind WhatsApp will not render, or the upload was refused —
  # and reading the code is a poor way to find out which.
  def call
    return refuse(unusable_reason) if !::Whatsapp.usable_header_image?(attachment)

    blob = attachment.blob

    # Streamed rather than downloaded whole: the picture can be several
    # megabytes, and it is on its way to a file either way.
    media_id = ::WhatsappApi::Client.new.media.upload(mime_type: blob.content_type) do |file|
      blob.download { |chunk| file.write(chunk) }
    end

    return media_id if media_id.present?

    refuse("upload returned no media id for #{describe(blob)}")
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] draft image upload failed: #{e.class} - #{e.message}")

    nil
  end

  private

    def attachment
      return @attachment if defined?(@attachment)

      @attachment = @resource&.image&.attachment
    end

    def refuse(reason)
      Rails.logger.info("[Whatsapp] draft image skipped: #{reason}")

      nil
    end

    # Reports the numbers rather than which of the two rules fired: both are on
    # the line, and one string beats three branches that say the same thing.
    def unusable_reason
      return "no picture attached" if attachment.blank? || !attachment.attached?

      "#{describe(attachment.blob)}, allowed are " \
        "#{::Whatsapp::HEADER_IMAGE_CONTENT_TYPES.join(", ")} " \
        "up to #{::Whatsapp::HEADER_IMAGE_MAX_BYTES} bytes"
    end

    def describe(blob)
      "#{blob.content_type} of #{blob.byte_size} bytes"
    end
end
