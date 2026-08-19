class Whatsapp::AiAssistant::MessageContext
  # What the bot knows about the message it is answering, while it answers it.
  # Held on Current for the length of one inbound job rather than threaded
  # through every flow service: the composing below reaches roughly a hundred
  # call sites of Whatsapp.phrase, and a keyword argument on each of them would
  # be a hundred edits to say the same thing.
  #
  # Absent by design outside the inbound path — the broadcast jobs, the phrase
  # generation job, a rails console. Nothing there has a citizen mid-sentence to
  # write for, so those keep the locale copy. ComposeReplyService returning early
  # on a missing context is what holds the approved notification wording.
  #
  # How many lines of one reply may be composed live. One, because a composed
  # line is written against the whole conversation rather than against its own
  # sentence: a body assembled from several phrases used to pay a completion per
  # fragment while the citizen waited, and the second of them was written
  # without knowing what the first had just said. The remaining fragments fall
  # back to the pre-generated wordings, which are already varied and already in
  # the right address form.
  MAX_COMPOSITIONS = 1

  attr_reader :conversation, :inbound_text, :previous_inbound_at

  # `previous_inbound_at` is the conversation's clock as it stood *before* this
  # message advanced it, and it has to be read here because it no longer exists
  # anywhere else: Inbound::ProcessMessageService overwrites last_inbound_at as
  # the first statement of its gate chain, so every reply downstream would
  # otherwise measure the gap as zero (CON-2982).
  #
  # `inbound_message_id` is this message's wa_message_id, held only so the dialog
  # digest can leave it out of the history it reports.
  def initialize(
    conversation:, inbound_text: nil, previous_inbound_at: nil, inbound_message_id: nil
  )
    @conversation = conversation
    @inbound_text = inbound_text
    @previous_inbound_at = previous_inbound_at
    @inbound_message_id = inbound_message_id
    @compositions_made = 0
  end

  # One digest per turn, shared by the assistant's system prompt and the reply
  # composer. Memoized here rather than in each of them: both want the same twelve
  # rows, and built separately they were two identical queries on every composed
  # message.
  def dialog_digest
    @dialog_digest ||= ::Whatsapp::AiAssistant::DialogDigest.new(
      account: @conversation.whatsapp_account,
      excluding_wa_message_id: @inbound_message_id
    )
  end

  def compositions_left?
    @compositions_made < MAX_COMPOSITIONS
  end

  # Counted whether or not the composition came back usable: a provider
  # answering slowly costs the wait either way, and the budget exists to bound
  # the wait rather than the spend.
  def count_composition!
    @compositions_made += 1
  end

  # The elapsed-gap instruction for this turn, so the composer and the system
  # prompt both read one answer rather than each measuring the clock.
  def gap_instruction_line
    ::Whatsapp::ConversationGap.instruction_line(@previous_inbound_at)
  end
end
