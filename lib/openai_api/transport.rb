# Whether the WhatsApp assistant talks to OpenAI through this client rather than
# through ruby_llm. It is the only surface in the app that does: every other AI
# caller reaches a model through Ai::RubyLlmFactory, which is what keeps the
# eleven configurable providers working — so the switch is gated on the
# configured provider actually being OpenAI as well as on being set. Selecting
# Anthropic or Gemini in /adm has to take the WhatsApp surface back to ruby_llm
# with it, or the setting would be describing a provider nobody is talking to.
module OpenaiApi::Transport
  TRANSPORT_SETTING = "ai.whatsapp_transport".freeze

  # The value that has to be written in the settings row, which has no /adm
  # control and defaults to nil. Renaming it away from the SDK it no longer uses
  # is safe for that reason and one more: until this client existed there was no
  # openai gem installed, so an installation that had the old value set could
  # only ever have raised on it.
  TRANSPORT_VALUE = "openai_api".freeze

  def self.enabled?
    return false if ::Ai::Settings.current_llm_provider != "openai"

    ::Setting[TRANSPORT_SETTING] == TRANSPORT_VALUE
  end
end
