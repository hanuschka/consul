class Whatsapp::AiAssistant::OptOutIntentService < ApplicationService
  # Whether a citizen asked to stop being written to in words the keyword list
  # cannot hold. "stop", "abmelden" and "unsubscribe" cover the citizens who
  # answer in exactly those; "bitte keine nachrichten mehr", "nehmt mich von der
  # liste" and "ich will das nicht mehr bekommen" all missed and were answered by
  # the assistant as conversation, which reads as the bot refusing to let go.
  #
  # Widening only. The keyword lists in ProcessMessageService keep deciding on
  # their own and are never asked about here, so an unreachable provider, a
  # timeout or an empty reply costs a paraphrase that goes unread — exactly what
  # happened before this existed — and can never leave a typed "STOP" unhonoured
  # or revoke an opt-out already written. IntentCheckService is what guarantees
  # that: every failure it can have answers false.
  #
  # Deliberately lopsided the other way round from the draft decision: there,
  # doubt costs a repeated question and a wrong yes publishes something nobody
  # approved. Here, doubt costs one unanswered paraphrase and a wrong yes
  # silences a channel the citizen wanted — so the instructions ask for
  # unmistakable, and everything else is answered as before.
  #
  # Cancelling is named as the thing this is not: mid-submission, "lass mal",
  # "abbrechen" and "doch nicht" end the draft and nothing else, and reading one
  # of them as leaving the channel would unsubscribe someone who only changed
  # their mind about one idea.
  INSTRUCTIONS = <<~TEXT.freeze
    A citizen writes to a participation portal's WhatsApp bot. Decide the single question of
    whether their message asks to stop receiving messages from this channel altogether —
    unsubscribing, opting out, being taken off the list, wanting no further messages.

    Answer true only when that reading is unmistakable, however they phrase it: "bitte keine
    nachrichten mehr", "nehmt mich von der liste", "ich möchte nichts mehr von euch hören", "hör
    auf mir zu schreiben", "please stop messaging me".

    Answer false for everything else, and in particular for:
    - cancelling or undoing what is in progress rather than leaving the channel — "abbrechen",
      "lass mal", "doch nicht", "das war ein fehler", "zurück"
    - declining, postponing or refusing one thing — an invitation to link an account, one
      question, one notification type
    - a complaint about too many messages that does not ask for them to end
    - a contribution, a question to the bot, small talk, or anything you cannot read with
      confidence as leaving the channel

    When in doubt, answer false.
  TEXT

  QUESTION = "True only when the message unmistakably asks to stop receiving messages from " \
             "this channel altogether.".freeze

  def initialize(inbound_text:)
    @inbound_text = inbound_text
  end

  def call
    Whatsapp::AiAssistant::IntentCheckService.call(
      inbound_text: @inbound_text,
      instructions: INSTRUCTIONS,
      question: QUESTION,
      label: "opt-out intent"
    )
  end
end
