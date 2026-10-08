class Adm::AiSettings::FormComponent < ApplicationComponent
  attr_reader :setting

  delegate :key, to: :setting

  def initialize(setting)
    @setting = setting
  end

  private

    def custom_model_required?
      key == "ai.llm_custom_model" && Setting["ai.llm_api_endpoint"].present?
    end

    def ai_provider_options
      RubyLLM.providers.map { |provider| [provider.display_name, provider.slug] }
    end

    def ai_model_options
      provider = Setting["ai.llm_provider"]
      return [] if provider.blank?

      ::Ai::ModelRegistry.chat_model_ids(provider).map { |model_id| [model_id, model_id] }
    end
end
