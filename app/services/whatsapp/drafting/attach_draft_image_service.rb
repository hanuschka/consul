class Whatsapp::Drafting::AttachDraftImageService < ApplicationService
  # The two ways a picture reaches a draft: the citizen's own upload, and the one
  # the portal generates from the prompt the drafting call already wrote. Both end
  # in the same ResourceImages::AttachService the web upload form uses, so a
  # picture attached by chat is indistinguishable from one attached on the site.
  #
  # Two entry points rather than one with a mode, because the two share almost
  # nothing: an upload is a download from WhatsApp bounded by the portal's own
  # image limit and attached as it arrived, and a generation is an external call
  # whose result has the AI marker written into it, sets the flags that put the
  # disclosure label on the page, and sets the column that records where the
  # picture came from.
  #
  # Returns true when a picture was attached. Failures are reported and answered
  # false rather than raised: the picture is optional, and losing the whole
  # submission over it would be the worse outcome.
  def self.from_upload(resource:, user:, media_id:)
    new(resource: resource, user: user).from_upload(media_id)
  end

  def self.from_generation(resource:, user:)
    new(resource: resource, user: user).from_generation
  end

  def initialize(resource:, user:)
    @resource = resource
    @user = user
  end

  # Downloaded through the same media resource the voice-note transcription uses,
  # and bounded by the portal's own image limit rather than a number invented here
  # — a picture the bot accepts must be one the website would have accepted too.
  def from_upload(media_id)
    return false if @resource.blank?
    return false if media_id.blank?

    media = download(media_id)

    return false if media.blank?

    ::ResourceImages::AttachService.from_bytes(
      resource: @resource,
      user: @user,
      bytes: media[:body],
      content_type: media[:mime_type]
    )

    true
  rescue StandardError => e
    report(e, "image attach")

    false
  end

  # From the prompt the drafting call produced and stored on the resource, falling
  # back to the title. Runs inline rather than in a job: the citizen is waiting on
  # the answer, and publishing has to happen after the picture is attached.
  def from_generation
    return false if @resource.blank?
    return false if generation_prompt.blank?

    response = ::DtApi::Client.new.ai.generate_image(prompt: generation_prompt)

    return false if !response&.success?

    attach_generated(response.parsed_response)
  rescue ::Images::MarkAiGeneratedService::MarkingFailedError => e
    report(e, "image marking")

    false
  rescue StandardError => e
    report(e, "image generation")

    false
  end

  private

    def download(media_id)
      ::WhatsappApi::Client.new.media.download(
        media_id, max_bytes: ::Image.max_file_size.megabytes
      )
    end

    def generation_prompt
      @resource.ai_image_prompt.presence || @resource.title
    end

    # Through from_generated_base64 rather than from_base64, which is the difference
    # between a marked picture and one that only looks like it. The marked route
    # writes the IPTC source type into the bytes and sets ai_generated on the Image,
    # which is what puts the disclosure label on the public page — a picture attached
    # the plain way carries neither, and a citizen reading the page has no way to
    # tell it from a photograph.
    #
    # A marking failure is left to rise out of here: Images::MarkAiGeneratedService
    # raises it so a caller has to decide, and from_generation answers it the same way
    # a failed generation is answered — no picture, and the assistant says so.
    # Publishing an unmarked generated picture is the one outcome worse than
    # publishing none.
    def attach_generated(response_body)
      return false if response_body["image"].blank?

      ::ResourceImages::AttachService.from_generated_base64(
        resource: @resource,
        user: @user,
        base64: response_body["image"],
        ai_system: ::DtApi::Resources::Ai.reported_provider(response_body),
        ai_system_version: ::DtApi::Resources::Ai.reported_model(response_body)
      )

      # The same column the web editor sets, so a picture's origin reads the same
      # however it was made.
      @resource.update_column(:generated_image, true)

      true
    end

    def report(exception, action)
      Rails.logger.error("[Whatsapp] #{action} failed: #{exception.class} - #{exception.message}")

      Sentry.capture_exception(exception, extra: { whatsapp_resource_id: @resource&.id })
    end
end
