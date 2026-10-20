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

  # Models that cannot switch reasoning off: they answer 400 for none and
  # minimal, so they are named the lowest effort they accept instead. Read only
  # for a model the registry does not list with its efforts; matched as
  # prefixes so dated snapshots of the same model are covered too.
  ALWAYS_REASONING_MODEL_PREFIXES = %w[gpt-6.1-sol gpt-6-astra].freeze
  ALWAYS_REASONING_LOWEST_EFFORT = "low".freeze

  EFFORTS_ASCENDING = %w[none minimal low medium high xhigh max].freeze

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

  # Whichever tier the temporary staging setting names, the cheap one until it
  # names another. Read by the WhatsApp chat services alone, and removed with
  # the setting once the comparison it exists for has been made.
  def self.whatsapp
    new(::Ai::Settings.whatsapp_model)
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

  # Every call runs at the model's own default effort, except where the request
  # schema forces one to be named. OpenAI itself is reached over the Responses
  # API, which takes tools at any effort, so nothing is named there. An endpoint
  # configured under the OpenAI provider with its own URL serves the
  # chat-completions schema, and from the GPT-5.5 generation on that refuses a
  # request carrying function tools and naming no effort — "set
  # reasoning_effort to 'none'". Withholding the parameter from such a portal
  # once broke every tool-carrying turn it made, the whole WhatsApp assistant
  # included.
  #
  # There the effort named is none, or the lowest the model accepts when it
  # cannot switch reasoning off. The one model it is withheld from is one
  # ruby_llm both knows and lists without reasoning: gpt-4.1 behind a LiteLLM
  # proxy to Azure answers 400 for the parameter. The remaining trade is a
  # custom id the registry has never heard of, served by a proxy that refuses
  # the parameter: a misconfiguration with a legible error, where the other was
  # every reply going missing.
  def reasoning_effort
    return nil if !::Ai::Settings.openai?
    return nil if ::Ai::Settings.standard_openai?

    info = registry_info

    return nil if info.present? && !info.supports?(:reasoning)

    lowest_accepted_effort(info)
  end

  # Only a model ruby_llm both knows and lists without function calling answers
  # false. A custom id, or one newer than the registry shipped with the gem, is
  # not in it at all — and withholding tools on that guess would take them away
  # from an installation they work on.
  def tools_supported?
    info = registry_info

    return true if info.blank?

    info.supports?(:function_calling)
  end

  private

    def lowest_accepted_effort(info)
      accepted_efforts = Array(info&.reasoning_option_values(:effort))
      lowest_effort = EFFORTS_ASCENDING.find { |effort| accepted_efforts.include?(effort) }

      return lowest_effort if lowest_effort.present?
      return ALWAYS_REASONING_LOWEST_EFFORT if always_reasoning?

      TOOL_REASONING_EFFORT
    end

    def always_reasoning?
      ALWAYS_REASONING_MODEL_PREFIXES.any? { |prefix| model.to_s.start_with?(prefix) }
    end

    def registry_info
      ::RubyLLM.models.find(model)
    rescue ::RubyLLM::ModelNotFoundError
      nil
    end
end
