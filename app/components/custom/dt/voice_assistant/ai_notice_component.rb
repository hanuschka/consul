class Dt::VoiceAssistant::AiNoticeComponent < ApplicationComponent
  def notice_text
    I18n.t("custom.voice_assistant.ai_notice")
  end
end
