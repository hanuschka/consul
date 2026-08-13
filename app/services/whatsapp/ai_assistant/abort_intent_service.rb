class Whatsapp::AiAssistant::AbortIntentService < ApplicationService
  # Whether a citizen wants to abandon what they are part-way through, in words
  # Whatsapp::FlowActions::ABORT_KEYWORDS cannot hold. "abbrechen" and "cancel"
  # cover the citizens who answer in exactly those; "lass mal", "vergiss es",
  # "ach doch nicht" and "ne, lieber nicht" all missed. A linked citizen is
  # usually caught by the assistant, but a guest submitter never reaches it —
  # ProcessMessageService#routed_by_assistant? refuses without a user — so at
  # awaiting_idea "ach lass mal, doch nicht" was drafted into a proposal.
  #
  # Two entry points because the question is asked at two moments and they are
  # not the same question. Unprompted, the message has to volunteer the intent;
  # answering the confirmation, a bare "ja" is the whole answer and means the
  # opposite of the "ja" that publishes a draft one step earlier.
  #
  # False on every failure, which IntentCheckService guarantees and which is the
  # reading the bot had before this existed: the flow carries on and the citizen
  # says it again.
  def self.volunteered(inbound_text:)
    new(
      inbound_text: inbound_text,
      instructions: VOLUNTEERED_INSTRUCTIONS,
      question: VOLUNTEERED_QUESTION,
      label: "abort intent"
    ).call
  end

  def self.answering_confirmation(inbound_text:)
    new(
      inbound_text: inbound_text,
      instructions: CONFIRMATION_INSTRUCTIONS,
      question: CONFIRMATION_QUESTION,
      label: "abort confirmation"
    ).call
  end

  # Deliberately lopsided towards carrying on. A false negative costs the
  # citizen one more message to say it again; a false positive throws away a
  # submission they were part-way through writing — which is also why the caller
  # confirms rather than acting on this outright.
  VOLUNTEERED_INSTRUCTIONS = <<~TEXT.freeze
    A citizen is part-way through submitting a contribution to a participation portal over
    WhatsApp — the bot has asked them for their idea, a category, a picture, or whether a draft is
    right. Decide the single question of whether their message means they want to abandon it.

    Answer true only when that reading is unmistakable, however they phrase it: "abbrechen", "lass
    mal", "vergiss es", "ach doch nicht", "ne, lieber nicht", "ich mach das später", "stop das".

    Answer false for everything else, and in particular for:
    - the answer the bot is waiting for — an idea, a correction, a description, a place
    - a refusal of one optional part rather than the whole thing — no picture, no location, no
      category
    - a question to the bot, hesitation, thinking out loud, or a complaint that is not a request
      to stop
    - asking to stop receiving messages from the channel altogether, which is a different thing

    When in doubt, answer false.
  TEXT

  VOLUNTEERED_QUESTION = "True only when the message unmistakably means the submission in " \
                         "progress should be abandoned.".freeze

  # The bot has just asked, in so many words, whether to cancel. So the message
  # is read as an answer to that question rather than as a statement about it,
  # and the bar is a plain yes.
  CONFIRMATION_INSTRUCTIONS = <<~TEXT.freeze
    A citizen is part-way through submitting a contribution to a participation portal over
    WhatsApp. The bot has just asked them whether it should cancel the submission. Decide whether
    their reply means yes, cancel it.

    Answer true for agreement, however they phrase it: "ja", "jup", "genau", "bitte", "ja mach
    das", "abbrechen", "ja lass uns aufhören".

    Answer false for a refusal — "nein", "doch nicht", "weiter", "lass uns weitermachen" — and for
    anything you cannot read with confidence as agreement, including a reply that answers the
    submission's own question instead of this one.

    When in doubt, answer false.
  TEXT

  CONFIRMATION_QUESTION = "True only when the reply agrees that the submission in progress " \
                          "should be cancelled.".freeze

  def initialize(inbound_text:, instructions:, question:, label:)
    @inbound_text = inbound_text
    @instructions = instructions
    @question = question
    @label = label
  end

  def call
    Whatsapp::AiAssistant::IntentCheckService.call(
      inbound_text: @inbound_text,
      instructions: @instructions,
      question: @question,
      label: @label
    )
  end
end
