class Whatsapp::AiAssistant::MessageContext
  # What the bot knows about the message it is answering, while it answers it.
  # Held on Current for the length of one inbound job rather than threaded
  # through every flow service: the live rewriting below reaches roughly a
  # hundred call sites of Whatsapp.phrase, and a keyword argument on each of
  # them would be a hundred edits to say the same thing.
  #
  # Absent by design outside the inbound path — the broadcast jobs, the phrase
  # generation job, a rails console. Nothing there has a citizen mid-sentence to
  # write for, so those keep the locale copy.
  #
  # How many lines of one reply may be rewritten live. A body assembled from
  # several phrases would otherwise pay a completion per fragment while the
  # citizen waits: two covers the sentence that carries the message and the one
  # that follows it, and the rest fall back to the pre-generated wordings, which
  # are already varied and already in the right address form.
  MAX_LIVE_REWRITES = 2

  attr_reader :conversation, :inbound_text

  def initialize(conversation:, inbound_text: nil)
    @conversation = conversation
    @inbound_text = inbound_text
    @rewrites_made = 0
  end

  def rewrites_left?
    @rewrites_made < MAX_LIVE_REWRITES
  end

  # Counted whether or not the rewrite came back usable: a provider answering
  # slowly costs the wait either way, and the budget exists to bound the wait
  # rather than the spend.
  def count_rewrite!
    @rewrites_made += 1
  end
end
