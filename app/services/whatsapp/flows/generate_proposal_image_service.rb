class Whatsapp::Flows::GenerateProposalImageService < Whatsapp::Flows::BaseService
  # The bot's own picture, from the prompt the drafting call already produced
  # and stored on the resource. Until now that prompt was written and never
  # used, so a proposal drafted in WhatsApp ended up without the image its web
  # equivalent gets.
  #
  # Runs inline rather than in a job: the citizen is waiting on the answer, and
  # publishing has to happen after the picture is attached, not before.
  # Returns true when a picture was attached.
  def call
    return false if draft_resource.blank?
    return false if prompt.blank?

    response = ::DtApi::Client.new.ai.generate_image(prompt: prompt)

    return false if !response&.success?

    attach(response.parsed_response["image"])
  rescue StandardError => e
    report(e, "image generation")

    false
  end

  private

    def prompt
      draft_resource.ai_image_prompt.presence || draft_resource.title
    end

    def attach(base64_image)
      return false if base64_image.blank?

      ResourceImages::AttachService.from_base64(
        resource: draft_resource, user: @conversation.user, base64: base64_image
      )

      # The same column the web editor sets, so a picture's origin reads the
      # same however it was made.
      draft_resource.update_column(:generated_image, true)

      true
    end
end
