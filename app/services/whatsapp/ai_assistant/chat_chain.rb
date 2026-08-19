class Whatsapp::AiAssistant::ChatChain
  # What ChatState is to the ruby_llm transport, this is to the Responses one:
  # the only thing about a conversation that survives between two turns, since
  # every inbound message is its own job. The difference is what gets written
  # down — ChatState stores the messages themselves, this stores the id of the
  # last response the provider is holding, because on that transport the history
  # is theirs.
  #
  # Counted in turns rather than in provider messages, because a chain has no
  # message count to read. The ceiling is not housekeeping: chaining bills every
  # previous input token in the chain back on each turn, so without one a long
  # conversation grows its own cost per message. Twenty-four turns is roughly the
  # conversation length ChatState's 48 provider messages worked out to.
  MAX_TURNS = 24

  # A chain older than the provider's thirty-day retention no longer exists, and
  # a conversation nobody has written to for a month is exactly that case.
  # Recognising it matters because the answer is to start a fresh chain and ask
  # again — failing the turn instead would leave a returning citizen with a bot
  # that has gone quiet for good.
  STALE_CHAIN_MESSAGE = /previous_response/i

  def self.stale?(error)
    return true if error.is_a?(::OpenAI::Errors::NotFoundError)
    return false if !error.is_a?(::OpenAI::Errors::BadRequestError)

    error.message.to_s.match?(STALE_CHAIN_MESSAGE)
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def previous_response_id
    stored["response_id"].presence
  end

  # The outputs a halted turn left owing, sent at the head of the next turn's
  # input. The provider rejects a chain whose newest response has a function call
  # nobody answered, so these are not optional — and they double as the note that
  # tells the model what the halting tool already did.
  #
  # Symbolised on the way out. They went into jsonb as symbol-keyed items and
  # come back string-keyed, which would have the next request carry two shapes of
  # the same item — the stored ones and the ones the loop builds fresh.
  def pending_tool_outputs
    Array(stored["pending_tool_outputs"]).map(&:deep_symbolize_keys)
  end

  def input_for(inbound_text)
    pending_tool_outputs + [{ role: "user", content: inbound_text }]
  end

  def save!(turn)
    next_turns = turns + 1

    return clear! if next_turns >= MAX_TURNS

    @conversation.store_ai_chain!(
      "response_id" => turn.response_id,
      "pending_tool_outputs" => turn.pending_tool_outputs,
      "turns" => next_turns
    )
  end

  def clear!
    @conversation.clear_ai_chain!
  end

  private

    def stored
      @conversation.stored_ai_chain || {}
    end

    def turns
      stored["turns"].to_i
    end
end
