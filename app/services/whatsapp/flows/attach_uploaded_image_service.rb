class Whatsapp::Flows::AttachUploadedImageService < Whatsapp::Flows::BaseService
  # The citizen's own photo. Downloaded through the same media resource the
  # voice-note transcription uses, and bounded by the portal's own image limit
  # rather than a number invented here — a picture the bot accepts must be one
  # the website would also have accepted through its upload form.
  def initialize(conversation:, media_id:)
    super(conversation: conversation)
    @media_id = media_id
  end

  # Returns true when the picture was attached, so the caller knows whether to
  # go on to publishing or to ask again.
  def call
    return false if @media_id.blank?
    return false if draft_resource.blank?

    media = download

    return false if media.blank?

    ResourceImages::AttachService.from_bytes(
      resource: draft_resource,
      user: @conversation.user,
      bytes: media[:body],
      content_type: media[:mime_type]
    )

    true
  rescue StandardError => e
    report(e, "image attach")

    false
  end

  private

    def download
      ::WhatsappApi::Client.new.media.download(
        @media_id, max_bytes: Image.max_file_size.megabytes
      )
    end
end
