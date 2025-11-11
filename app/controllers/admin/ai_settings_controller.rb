class Admin::AiSettingsController < Admin::BaseController
  helper_method :ai_provider_options, :ai_model_options

  def index
    @ai_settings = Setting.where("key LIKE ?", "llm.%").order(:key)
  end

  def update
    @setting = Setting.find(params[:id])
    @setting.update!(settings_params)

    respond_to do |format|
      format.html { redirect_to admin_ai_settings_path, notice: t("admin.ai_settings.flash.updated") }
      format.js
    end
  end

  private

    def settings_params
      params.require(:setting).permit(:value)
    end

    def ai_provider_options
      RubyLLM.providers.map { |p| [p.name, p.name.downcase] }
    end

    def ai_model_options
      provider = Setting["llm.provider"]
      return [] unless provider.present?

      RubyLLM.models.by_provider(provider.to_sym)
        .filter {|m| m.modalities.output.include?("text") }
        .sort_by { |model| model.created_at || Time.new(2000) }
        .reverse
        .map { |model| [model.id, model.id] }
    end
end
