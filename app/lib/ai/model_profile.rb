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

  # Named only where the catalogue is known to be OpenAI's own. Behind a custom
  # endpoint the model is whatever that endpoint serves, and a parameter it does
  # not recognise comes back as a 400 rather than being ignored.
  def reasoning_effort
    return nil if !::Ai::Settings.standard_openai?

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
