class Adm::AiSettingsController < Adm::BaseController
  helper_method :show_api_endpoint?, :show_model_field?, :show_custom_model_field?,
    :endpoint_without_custom_model?, :ai_feature_enabled?,
    :default_llm_model_in_use?, :effective_llm_model,
    :non_default_provider?, :default_api_key_in_use?,
    :highlight_llm_model?, :highlight_api_key?

  def index
    authorize [:adm, Setting], :index?, policy_class: Adm::AiSettingPolicy
    @ai_settings = policy_scope(Setting, policy_scope_class: Adm::AiSettingPolicy::Scope)
      .where("key LIKE ?", "ai.%")
      .order(:key)
    @evaluation_context_setting =
      @ai_settings.find { |setting| setting.key == Ai::EvaluationContext::SETTING_KEY }

    @breadcrumbs = [
      { name: t("adm.ai_settings.index.title"), icon: "smart_toy" }
    ]
  end

  def update
    @setting = Setting.find(params[:id])
    authorize [:adm, @setting], :update?, policy_class: Adm::AiSettingPolicy

    if clearing_required_custom_model?
      redirect_to adm_ai_settings_path, alert: t("adm.ai_settings.flash.custom_model_required")
      return
    end

    @setting.update!(settings_params)

    redirect_to adm_ai_settings_path, notice: t("adm.ai_settings.flash.updated")
  end

  def update_api_key
    authorize [:adm, Setting], :update_api_key?, policy_class: Adm::AiSettingPolicy

    api_key = ExternalApiKey.find_or_initialize_by(
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

    def endpoint_without_custom_model?
      Setting["ai.llm_api_endpoint"].present? && Setting["ai.llm_custom_model"].blank?
    end

    def ai_feature_enabled?
      Ai::Settings.feature_enabled?
    end

    def default_llm_model_in_use?
      !show_model_field? && !show_custom_model_field?
    end

    def effective_llm_model
      Ai::Settings.current_llm_model
    end

    def non_default_provider?
      provider = Setting["ai.llm_provider"].to_s.downcase

      provider.present? && provider != "openai"
    end

    def custom_api_key_present?
      return @custom_api_key_present if defined?(@custom_api_key_present)

      @custom_api_key_present =
        ExternalApiKey
          .find_by(name: "api_key", service: Ai::Settings.current_llm_provider)
          &.value
          .present?
    end

    def default_api_key_in_use?
      !custom_api_key_present?
    end

    def highlight_llm_model?
      non_default_provider? && Setting["ai.llm_model"].blank?
    end

    def highlight_api_key?
      return false if custom_api_key_present?

      non_default_provider? || Setting["ai.llm_api_endpoint"].present?
    end

    def clearing_required_custom_model?
      @setting.key == "ai.llm_custom_model" &&
        settings_params[:value].blank? &&
        Setting["ai.llm_api_endpoint"].present?
    end
end
