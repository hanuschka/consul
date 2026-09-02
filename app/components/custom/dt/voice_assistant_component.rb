class Dt::VoiceAssistantComponent < ApplicationComponent
  attr_reader :assistant_codename, :projekt_phase

  def initialize(assistant_codename:, projekt_phase: nil)
    @assistant_codename = assistant_codename
    @projekt_phase = projekt_phase
  end

  def create_session_url
    helpers.voice_assistant_create_session_v2_path
  end

  def render?
    Ai::Settings.ai_available?
  end

  def title
    I18n.t("custom.voice_assistant.title")
  end

  def dock_name
    I18n.t("custom.voice_assistant.dock_name")
  end

  def open_label
    I18n.t("custom.voice_assistant.open")
  end

  def starting_label
    I18n.t("custom.voice_assistant.starting")
  end

  def listening_label
    I18n.t("custom.voice_assistant.listening")
  end

  def muted_label
    I18n.t("custom.voice_assistant.muted")
  end

  def mic_start_label
    I18n.t("custom.voice_assistant.mic_start")
  end

  def mic_stop_label
    I18n.t("custom.voice_assistant.mic_stop")
  end

  def mic_unmute_label
    I18n.t("custom.voice_assistant.mic_unmute")
  end

  def close_label
    I18n.t("custom.voice_assistant.close")
  end
end
