class Admin::AiSettingsController < Admin::BaseController
  helper_method :show_api_endpoint?, :show_model_field?, :show_custom_model_field?

  def index
    @ai_settings = Setting
      .where("key LIKE ?", "ai.%")
      .where.not(key: ::Ai::Settings::WHATSAPP_MODEL_TIER_SETTING_KEY)
      .order(:key)
  end

  def update
    if params[:external_api_key]
      update_api_key
    else
      update_setting
    end
  end

  private

    def update_setting
      @setting = Setting.find(params[:id])
      provider_change = changing_llm_provider?

      @setting.update!(settings_params)
      Ai::Settings.reset_llm_model! if provider_change

      respond_to do |format|
        format.html {
          redirect_to admin_ai_settings_path, notice: t("admin.ai_settings.flash.updated")
        }
        format.js
      end
    end

    def update_api_key
      api_key = ExternalApiKey.find_by(name: api_key_params[:name], service: api_key_params[:service])
      api_key.update!(api_key_params)

      respond_to do |format|
        format.html {
          redirect_to admin_ai_settings_path, notice: t("admin.ai_settings.flash.updated")
        }
        format.js
      end
    end

    def settings_params
      params.require(:setting).permit(:value)
    end

    def api_key_params
      params.require(:external_api_key).permit(:name, :service, :value)
    end

    def show_api_endpoint?
      provider = Setting["ai.llm_provider"].to_s.downcase

      ["openai", "ollama", "gemini"].include?(provider)
    end

    # OpenAI is included even though it has a built-in default: when the provider
    # changes what a model accepts, the instance must be able to move off the
    # default here rather than wait for a deploy. Leaving the field empty keeps
    # Ai::Settings::DEFAULT_GPT_MODEL.
    def changing_llm_provider?
      @setting.key == "ai.llm_provider" && @setting.value != settings_params[:value]
    end

    def show_model_field?
      provider = Setting["ai.llm_provider"].to_s.downcase

      provider != "ollama" && Setting["ai.llm_api_endpoint"].blank?
    end

    def show_custom_model_field?
      provider = Setting["ai.llm_provider"].to_s.downcase

      provider == "ollama" || Setting["ai.llm_api_endpoint"].present?
    end
end
