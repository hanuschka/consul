class Admin::AiSettingsController < Admin::BaseController
  helper_method :show_api_endpoint?, :show_model_field?, :show_custom_model_field?

  def index
    @ai_settings = Setting.where("key LIKE ?", "ai.%").order(:key)
    service = Setting["ai.llm_provider"].to_s.downcase
    @api_key = ExternalApiKey.find_or_create_by(name: "api_key", service: service)
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
      @setting.update!(settings_params)

      respond_to do |format|
        format.html {
          redirect_to admin_ai_settings_path, notice: t("admin.ai_settings.flash.updated")
        }
        format.js
      end
    end

    def update_api_key
      api_key = ExternalApiKey.find_or_create_by(name: api_key_params[:name], service: api_key_params[:service])
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
      provider = Setting["ai.llm_provider"]
      provider.to_s.downcase == "openai"
    end

    def show_model_field?
      provider = Setting["ai.llm_provider"]
      provider.to_s.downcase != "ollama"
    end

    def show_custom_model_field?
      provider = Setting["ai.llm_provider"]
      provider.to_s.downcase == "ollama"
    end
end
