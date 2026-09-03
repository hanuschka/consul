# The four decisions an AI call has to make before it can be sent — which model,
# over which transport, whether a reasoning effort may be named, whether tools
# may be attached — answered together from the three settings that determine all
# of them. Read a tier here and nothing downstream has to know a provider name:
# an instance pointed at Anthropic, at an OpenAI-compatible proxy, or at a local
# Ollama gets a profile that is already correct for it.
class Ai::ModelProfile
  RESPONSES = :responses
  RUBY_LLM = :ruby_llm

  # Chat Completions refuses function tools from the GPT-5.5 generation onward
  # unless reasoning is switched off explicitly, and a request that names no
  # effort is given the model's own default rather than none.
  TOOL_REASONING_EFFORT = "none".freeze

  def self.default
    new(::Ai::Settings.current_llm_model)
  end

  # The cheap tier, for the short judgements made while someone waits on the
  # other end of a chat — routing a message, rewording one line.
  def self.fast
    new(::Ai::Settings.fast_model)
  end

  # The cheapest tier, for classifying candidates a query has already narrowed.
  def self.ultrafast
    new(::Ai::Settings.ultrafast_model)
  end

  attr_reader :model

  def initialize(model)
    @model = model
  end

  def transport
    return RESPONSES if ::OpenaiApi::Transport.enabled?

    RUBY_LLM
  end

  def responses?
    transport == RESPONSES
  end

  # Named for any endpoint configured under the OpenAI provider, custom or not,
  # because reasoning_effort belongs to the chat-completions request schema that
  # endpoint serves. Gating it on the *catalogue* being OpenAI's own instead was
  # an outage rather than caution: from the GPT-5.5 generation on, a request
  # carrying function tools and naming no effort is refused outright — "set
  # reasoning_effort to 'none'" — so withholding the parameter from a portal
  # with a custom endpoint broke every tool-carrying turn it made, the whole
  # WhatsApp assistant included.
  #
  # The trade is a proxy serving a catalogue that has never heard of the
  # parameter, which answers 400 for it. That one is a misconfiguration with a
  # legible error; the other was every reply going missing.
  def reasoning_effort
    return nil if !::Ai::Settings.openai?

    TOOL_REASONING_EFFORT
  end

  # Only a model ruby_llm both knows and lists without function calling answers
  # false. A custom id, or one newer than the registry shipped with the gem, is
  # not in it at all — and withholding tools on that guess would take them away
  # from an installation they work on.
  def tools_supported?
    info = registry_info

    return true if info.blank?

    info.supports_functions?
  end

  private

    def registry_info
      ::RubyLLM.models.find(model)
    rescue ::RubyLLM::ModelNotFoundError
      nil
    end
end
