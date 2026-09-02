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
      RubyLLM.providers.map { |p| [p.name, p.name.downcase] }
    end

    def ai_model_options
      provider = Setting["ai.llm_provider"]
      return [] if provider.blank?

      RubyLLM
        .models
        .refresh!
        .by_provider(provider.to_sym)
        .chat_models
        .sort_by { |model| model.created_at || Time.new(2000) }.reverse
        .map { |model| [model.id, model.id] }
    end
end
