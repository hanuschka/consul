class Whatsapp::Flows::AskRevisionService < Whatsapp::Flows::BaseService
  # The revision loop: asking what should change, reading the answer, and
  # applying a change the citizen already named. Entered from the draft card
  # and from the final preview, which is why the origin is recorded — the two
  # owe different steps afterwards.
  def self.ask(conversation:)
    new(conversation: conversation).ask
  end

  def self.enter(conversation:, correction:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id).enter(correction)
  end

  def self.handle_answer(conversation:, text:, verdict:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id)
      .handle_answer(text, verdict)
  end

  def initialize(conversation:, inbound_message_id: nil)
    super(conversation: conversation)
    @inbound_message_id = inbound_message_id
  end

  # The change the citizen already named, applied at once rather than asked
  # for again: "ja aber der Titel ist zu lang" has said everything the
  # revision needs, and answering it with "what should I change?" asks them to
  # repeat themselves. Where they named none, that question is still the way
  # forward.
  def enter(correction)
    return ask if correction.blank?

    apply(correction)
  end

  # The step it was asked from is recorded before it is overwritten. A citizen
  # who answers the revision question with "doch, passt so" rejoins the flow
  # where they left it, and the draft card and the preview leave it in
  # different places — one still owes a picture, the other has already sent
  # it.
  def ask
    @conversation.merge_context!(revision_origin: @conversation.step)
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_REVISION)

    send_question
  end

  # The step exists to collect a correction, so the citizen's own words are
  # taken as one and the verdict answers only the narrower question of whether
  # they changed their mind instead. "doch egal, passt so" and "ach, lass es
  # wie es ist" used to be handed to the rewriter as instructions, spending a
  # generation to alter a draft nobody had asked to alter.
  #
  # The extracted correction is deliberately not used here, only the verdict:
  # this step already asked "what should I change?", so the whole message is
  # the answer, and narrowing it to what a model read out of it could drop
  # half of what the citizen wrote.
  def handle_answer(text, verdict)
    correction = text.to_s.strip

    return send_question if correction.blank?
    return resume_flow_position if verdict == :publish

    apply(correction)
  end

  private

    def send_question
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.proposal.ask_revision")
      )
    end

    # Back where the revision question was asked from: the draft card owes the
    # picture and the pin, the preview only the pin. A missing origin — a
    # conversation that was already at this step when the recording was added
    # — takes the longer way round, which can ask for a picture that is
    # already attached but cannot publish anything the citizen has not seen.
    def resume_flow_position
      if @conversation.context["revision_origin"] ==
         Whatsapp::Conversation::Step::AWAITING_FINAL_CONFIRMATION
        return Whatsapp::Flows::AskLocationService.ask(
          conversation: @conversation, inbound_message_id: @inbound_message_id
        )
      end

      Whatsapp::Flows::ProposalImageService.ask(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      )
    end

    # Shared by the answer to the revision question and the correction read
    # out of a typed answer at the draft card: both are one change to apply,
    # and the round counter belongs to the revision itself rather than to
    # whichever step happened to collect it.
    #
    # The correction is passed on its own. It used to be appended to the
    # citizen's original idea and the whole draft written again from the pair,
    # which meant every round rewrote text they had already approved.
    def apply(correction)
      # Checked here as well as inside the build, because the round counter
      # below must not move for a revision the phase no longer permits.
      return if refuse_if_not_permitted

      @conversation.update!(revisions_count: @conversation.revisions_count + 1)

      Whatsapp::Flows::BuildDraftService.from_revision(
        conversation: @conversation, correction: correction,
        inbound_message_id: @inbound_message_id
      )
    end
end
