class Dt::VoiceAssistant::AiNoticeComponent < ApplicationComponent
  def notice_text
    I18n.t("custom.voice_assistant.ai_notice")
  end

  def details_label
    I18n.t("custom.voice_assistant.ai_notice_details_label")
  end

  def details
    @details ||= I18n.t("custom.voice_assistant.ai_notice_details")
  end
end
