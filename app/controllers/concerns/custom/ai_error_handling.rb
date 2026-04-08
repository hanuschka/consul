module AiErrorHandling
  extend ActiveSupport::Concern

  private

  def check_ai_model_configured
    unless Ai::Settings.llm_model_set?
      render json: { status: { message: I18n.t("ai.errors.model_not_configured") }}, status: 400
      return false
    end
    true
  end
end
