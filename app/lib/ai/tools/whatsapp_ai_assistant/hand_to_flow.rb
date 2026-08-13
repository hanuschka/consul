class Ai::Tools::WhatsappAiAssistant::HandToFlow < Ai::Tools::WhatsappAiAssistant::BaseTool
  # What a message can do to the step it lands on, besides being read as
  # content. The verdict travels on the hand-off so the flow never pays a
  # second completion to re-derive what the router already read; anything
  # outside the list is taken as answer, which every step treats as "just the
  # message".
  DECISIONS = %w[answer publish revise skip].freeze

  DEFAULT_DECISION = "answer".freeze

  description "Hands this message, word for word, to the guided submission flow, which then " \
              "replies instead of you. Call it whenever the message is part of an ongoing " \
              "submission rather than a question to you: the citizen describing their idea, " \
              "answering the step's question, confirming or rejecting a draft, saying what to " \
              "change, or picking a phase. Never paraphrase, summarise or answer such a " \
              "message yourself: the flow reads the original wording. When unsure whether a " \
              "message is flow input or a question during an open submission, call this."

  params do
    string :decision,
      description: "What the message does to the current step. publish: they plainly agree " \
                   "the draft or preview should go in as it stands. revise: they want " \
                   "something changed, however they say it — also when they agree and ask for " \
                   "a change in one breath. skip: they decline the optional photo or location " \
                   "pin the step just asked for. answer: everything else — the idea, the " \
                   "correction text, a place, any ordinary reply. Publishing cannot be taken " \
                   "back: when in doubt, never publish. Use answer when unsure."
    optional :correction,
      description: "Only with decision revise: the change they asked for, in their own " \
                   "language, as an instruction to whoever rewrites the draft. Null when " \
                   "they said they want a change but not what it should be; never invent one." do
      string
    end
  end

  def initialize(conversation:)
    super

    @requested = false
    @decision = DEFAULT_DECISION
    @correction = nil
  end

  # An unknown decision is read as answer rather than errored back: the tool
  # halts the turn either way, so the model gets no second try, and answer is
  # the reading every step survives — it re-asks instead of acting.
  def execute(decision:, correction: nil)
    @requested = true
    @decision = DECISIONS.include?(decision.to_s) ? decision.to_s : DEFAULT_DECISION
    @correction = correction.presence

    halt("Handed the message to the guided submission flow.")
  end

  def requested?
    @requested
  end

  def decision
    @decision.to_sym
  end

  def correction
    @correction
  end
end
