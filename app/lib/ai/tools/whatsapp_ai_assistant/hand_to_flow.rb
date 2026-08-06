class Ai::Tools::WhatsappAiAssistant::HandToFlow < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Hands this message, word for word, to the guided submission flow, which then " \
              "replies instead of you. Call it whenever the message is part of an ongoing " \
              "submission rather than a question to you: the citizen describing their idea, " \
              "confirming or rejecting a draft, saying what to change, or picking a phase. " \
              "Takes no arguments, because the flow reads the original wording, not your " \
              "version of it. When unsure whether a message is flow input or a question during " \
              "an open submission, call this."

  def initialize(conversation:)
    super

    @requested = false
  end

  def execute
    @requested = true

    halt("Handed the message to the guided submission flow.")
  end

  def requested?
    @requested
  end
end
