class Admin::AiSettings::FormComponent < ApplicationComponent
  attr_reader :setting, :key

  def initialize(setting, key)
    @setting = setting
    @key = key
  end

  private

    def ai_provider_options
      RubyLLM.providers.map { |provider| [provider.display_name, provider.slug] }
    end

    def ai_model_options
      provider = Setting["ai.llm_provider"]
      return [] unless provider.present?

      ::Ai::ModelRegistry.chat_model_ids(provider).map { |model_id| [model_id, model_id] }
    end
end
