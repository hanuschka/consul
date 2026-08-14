class Whatsapp::Inbound::StepDispatch
  # The last gate: routes a message nothing above claimed to the step the
  # conversation is waiting on. Acts on the routing object's already-made
  # reading — it never asks a model itself. The assistant's own button
  # replies leave the step at idle, which is why idle falls through to the
  # main menu.

  # The model's own step map, aliased so every `when` below is a constant
  # reference: a typo is a NameError at load rather than a case branch that
  # never matches and reads as a silently ignored message.
  Step = Whatsapp::Conversation::Step

  def initialize(conversation:, reading:, routing:)
    @conversation = conversation
    @reading = reading
    @routing = routing
  end

  def call
    case conversation.step
    when Step::AWAITING_IDEA
      Whatsapp::Flows::AskIdeaService.handle_answer(
        conversation:, text: inbound_text, inbound_message_id:
      )
    when Step::AWAITING_CATEGORY
      Whatsapp::Flows::AskDraftChoiceService.category(conversation:)
    when Step::AWAITING_SENTIMENT
      Whatsapp::Flows::AskDraftChoiceService.sentiment(conversation:)
    when Step::AWAITING_DUPLICATE_DECISION
      Whatsapp::Flows::AskDuplicateChoiceService.handle_answer(conversation:)
    when Step::AWAITING_DRAFT_DECISION
      Whatsapp::Flows::PresentDraftService.handle_decision(
        conversation:, verdict: flow_verdict, correction: flow_correction,
        inbound_message_id:
      )
    when Step::AWAITING_IMAGE_CHOICE
      Whatsapp::Flows::ProposalImageService.handle_choice(
        conversation:, verdict: flow_verdict, inbound_message_id:
      )
    when Step::AWAITING_IMAGE_UPLOAD
      Whatsapp::Flows::ProposalImageService.handle_upload(
        conversation:, image_id: inbound_image_id, verdict: flow_verdict,
        inbound_message_id:
      )
    when Step::AWAITING_LOCATION
      Whatsapp::Flows::AskLocationService.handle_answer(
        conversation:, location: inbound_location, verdict: flow_verdict,
        inbound_message_id:
      )
    when Step::AWAITING_FINAL_CONFIRMATION
      Whatsapp::Flows::ConfirmSubmissionService.handle_decision(
        conversation:, verdict: flow_verdict, correction: flow_correction,
        inbound_message_id:
      )
    when Step::AWAITING_REVISION
      Whatsapp::Flows::AskRevisionService.handle_answer(
        conversation:, text: inbound_text, verdict: flow_verdict,
        inbound_message_id:
      )
    when Step::AWAITING_COMMENT
      Whatsapp::Flows::CommentService.create(conversation:, body: inbound_text)
    when Step::AWAITING_NOTIFICATION_SETTINGS
      Whatsapp::Flows::NotificationSettingsService.call(conversation:)
    when Step::AWAITING_UNLINK_CONFIRMATION
      Whatsapp::Flows::UnlinkService.ask(conversation:)
    when Step::AWAITING_RESUME_DECISION
      Whatsapp::Flows::ResumeOrRestartService.call(conversation:)
    else
      handle_idle_message
    end
  end

  private

    attr_reader :conversation

    def inbound_text
      @reading.text
    end

    def inbound_message_id
      @reading.message_id
    end

    def inbound_image_id
      @reading.image_id
    end

    def inbound_location
      @reading.location
    end

    def flow_verdict
      @routing.verdict
    end

    def flow_correction
      @routing.correction
    end

    # Nothing in progress and nothing the assistant could route. An unlinked
    # guest submitter reaches here too, and the menu answers them with the
    # help list rather than three buttons they mostly cannot use.
    def handle_idle_message
      Whatsapp::Flows::MainMenuService.greeting(conversation:)
    end
end
