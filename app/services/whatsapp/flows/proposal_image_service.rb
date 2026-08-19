class Whatsapp::Flows::ProposalImageService < Whatsapp::Flows::BaseService
  # The whole picture step: the offer, the two ways a picture can arrive — the
  # citizen's own upload and the bot's generated one — and the answers a
  # citizen can give while the step is open. One service because every entry
  # ends in the same two exits: on to the location question, or on to the
  # final preview once a picture is attached.
  def self.ask(conversation:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id).ask
  end

  def self.ask_upload(conversation:)
    new(conversation: conversation).ask_upload
  end

  def self.handle_choice(conversation:, verdict:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id).handle_choice(verdict)
  end

  def self.handle_upload(conversation:, image_id:, verdict:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id)
      .handle_upload(image_id, verdict)
  end

  def self.generate(conversation:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id).generate
  end

  def initialize(conversation:, inbound_message_id: nil)
    super(conversation: conversation)
    @inbound_message_id = inbound_message_id
  end

  # Asked once the draft has been confirmed and before anything is published:
  # a picture is offered, never assumed. Three pills is exactly WhatsApp's
  # limit, which is also why "skip" is a button rather than an implied timeout
  # — a citizen who wants no picture must be able to say so in one tap.
  #
  # The picture is offered between confirming the draft and publishing it, so
  # the permission re-check happens here: refusing after a citizen has already
  # chosen and uploaded an image would waste the one thing they had to do work
  # for.
  #
  # A phase with title images switched off has nothing to ask, so it moves on
  # on the spot — exactly what the skip pill does. Asking anyway would offer a
  # picture the resource cannot carry.
  #
  # A citizen who already said they have no photo is the same situation for a
  # different reason: the question has an answer, so putting it reads as not
  # having listened. They said so in the message that opened the submission and
  # the drafting call recorded it (CON-2982). Only a declined photo skips —
  # someone who merely mentioned a photo they are about to send still gets the
  # step, because the upload has to happen somewhere.
  def ask
    return ask_location if !@conversation.image_question_pending?
    return if refuse_if_not_permitted

    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_IMAGE_CHOICE)

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.ask_image"),
      buttons: choice_buttons
    )
  end

  def ask_upload
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_IMAGE_UPLOAD)

    send_upload_prompt("whatsapp.bot.proposal.image_upload_prompt")
  end

  # The picture question answered in words. Both this step and the upload
  # step carry a skip pill and understood nothing but the pill, so "kein foto"
  # was answered by asking for the photo again — which is the one reply that
  # cannot be read as anything but a refusal.
  def handle_choice(verdict)
    return ask_location if verdict == :skip

    ask
  end

  # A photo sent while the bot is waiting for one, or the citizen saying there
  # will not be one. Anything else at this step is answered by asking again
  # rather than by silently publishing without the picture they said they
  # wanted to send.
  def handle_upload(image_id, verdict)
    return ask_location if image_id.blank? && verdict == :skip

    return send_upload_prompt("whatsapp.bot.proposal.image_upload_prompt") if
      image_id.blank?

    return send_upload_prompt("whatsapp.bot.proposal.image_failed") if !attach_upload(image_id)

    Whatsapp::Send.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.image_received")
    )

    Whatsapp::Flows::ConfirmSubmissionService.call(conversation: @conversation)
  end

  # Generation is a slow external call, so the citizen is told it started and
  # the typing bubble covers the wait. A failure goes on anyway: the picture
  # was optional, and losing the proposal over it would be the worse outcome.
  def generate
    Whatsapp::Send.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.image_generating")
    )
    Whatsapp::Send.typing(message_id: @inbound_message_id)

    if !generate_image
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.proposal.image_generate_failed")
      )
    end

    Whatsapp::Flows::ConfirmSubmissionService.call(conversation: @conversation)
  end

  private

    def ask_location
      Whatsapp::Flows::AskLocationService.ask(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      )
    end

    def choice_buttons
      [
        Whatsapp::FlowActions.button(
          action: :image_upload, label_key: "whatsapp.bot.buttons.image_upload"
        ),
        Whatsapp::FlowActions.button(
          action: :image_generate, label_key: "whatsapp.bot.buttons.image_generate"
        ),
        Whatsapp::FlowActions.image_skip_button(@conversation)
      ]
    end

    # Every prompt at the upload step carries the same way out, so the citizen
    # is never stuck waiting to be asked for a photo they cannot send.
    #
    # The rights notice is joined here rather than written into each prompt,
    # so the ask, the re-ask and the failure all carry it by construction.
    # Plain I18n.t like the consent line: telling someone what they are
    # responsible for is not a sentence to hand to the rephraser.
    def send_upload_prompt(body_key)
      body = [
        Whatsapp.phrase(body_key),
        I18n.t("whatsapp.bot.proposal.image_rights_notice")
      ].join("\n\n")

      Whatsapp::Send.buttons(
        account: account,
        body: body,
        buttons: [Whatsapp::FlowActions.image_skip_button(@conversation)]
      )
    end

    # The citizen's own photo. Downloaded through the same media resource the
    # voice-note transcription uses, and bounded by the portal's own image
    # limit rather than a number invented here — a picture the bot accepts
    # must be one the website would also have accepted through its upload
    # form. Returns true when the picture was attached, so the caller knows
    # whether to go on to publishing or to ask again.
    def attach_upload(media_id)
      return false if media_id.blank?
      return false if draft_resource.blank?

      media = download(media_id)

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

    def download(media_id)
      ::WhatsappApi::Client.new.media.download(
        media_id, max_bytes: Image.max_file_size.megabytes
      )
    end

    # The bot's own picture, from the prompt the drafting call already
    # produced and stored on the resource. Until now that prompt was written
    # and never used, so a proposal drafted in WhatsApp ended up without the
    # image its web equivalent gets.
    #
    # Runs inline rather than in a job: the citizen is waiting on the answer,
    # and publishing has to happen after the picture is attached, not before.
    # Returns true when a picture was attached.
    def generate_image
      return false if draft_resource.blank?
      return false if generation_prompt.blank?

      response = ::DtApi::Client.new.ai.generate_image(prompt: generation_prompt)

      return false if !response&.success?

      attach_generated(response.parsed_response["image"])
    rescue StandardError => e
      report(e, "image generation")

      false
    end

    def generation_prompt
      draft_resource.ai_image_prompt.presence || draft_resource.title
    end

    def attach_generated(base64_image)
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
