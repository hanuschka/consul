# OpenAI's Responses API through the official SDK, for the WhatsApp assistant
# only. Every other AI caller in the app reaches a model through
# Ai::RubyLlmFactory, which is what keeps the eleven configurable providers
# working — so this transport is gated on the configured provider actually being
# OpenAI as well as on the switch itself. Selecting Anthropic or Gemini in /adm
# has to take the WhatsApp surface back to ruby_llm with it, or the setting
# would be describing a provider nobody is talking to.
module Ai::OpenaiSdk
  TRANSPORT_SETTING = "ai.whatsapp_transport".freeze
  TRANSPORT_VALUE = "openai_sdk".freeze

  def self.enabled?
    return false if ::Ai::Settings.current_llm_provider != "openai"

    ::Setting[TRANSPORT_SETTING] == TRANSPORT_VALUE
  end
end
