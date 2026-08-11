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

  def call
    return if !::Whatsapp.usable_header_image?(attachment)

    ::WhatsappApi::Client.new.media.upload(
      bytes: attachment.blob.download,
      mime_type: attachment.blob.content_type
    )
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] draft image upload failed: #{e.class} - #{e.message}")

    nil
  end

  private

    def attachment
      return @attachment if defined?(@attachment)

      @attachment = @resource&.image&.attachment
    end
end
