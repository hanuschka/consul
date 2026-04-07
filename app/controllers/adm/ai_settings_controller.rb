class Adm::AiSettingsController < Adm::BaseController
  helper_method :show_api_endpoint?, :show_model_field?, :show_custom_model_field?

  def index
    authorize [:adm, Setting], :index?, policy_class: Adm::AiSettingPolicy
    @ai_settings = policy_scope(Setting, policy_scope_class: Adm::AiSettingPolicy::Scope)
      .where("key LIKE ?", "ai.%")
      .order(:key)

    @breadcrumbs = [
      { name: t("adm.ai_settings.index.title"), icon: "smart_toy" }
    ]
  end

  def update
    @setting = Setting.find(params[:id])
    authorize [:adm, @setting], :update?, policy_class: Adm::AiSettingPolicy
    @setting.update!(settings_params)

    redirect_to adm_ai_settings_path, notice: t("adm.ai_settings.flash.updated")
  end

  def update_api_key
    authorize [:adm, Setting], :update_api_key?, policy_class: Adm::AiSettingPolicy

    api_key = ExternalApiKey.find_by(
      name: api_key_params[:name],
      service: api_key_params[:service]
    )
    api_key.update!(api_key_params)

    redirect_to adm_ai_settings_path, notice: t("adm.ai_settings.flash.updated")
  end

  private

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

    def show_model_field?
      provider = Setting["ai.llm_provider"].to_s.downcase

      !provider.in?(["ollama", "openai"]) && Setting["ai.llm_api_endpoint"].blank?
    end

    def show_custom_model_field?
      provider = Setting["ai.llm_provider"].to_s.downcase

      provider == "ollama" || Setting["ai.llm_api_endpoint"].present?
    end
end
