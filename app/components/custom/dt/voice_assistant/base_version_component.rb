class Dt::VoiceAssistant::BaseVersionComponent < ApplicationComponent
  attr_reader :version

  def initialize(version:)
    @version = version
  end

  def root_class
    "voice-assistant-v#{version}"
  end

  def create_session_url
    helpers.voice_assistant_create_session_v2_path
  end

  def codename
    "proposal_voice_assistant"
  end

  def ui_name
    I18n.t("custom.voice_assistant_designs.ui_name", n: version)
  end

  def style_name
    I18n.t("custom.voice_assistant_designs.styles.v#{version}.name")
  end

  def style_desc
    I18n.t("custom.voice_assistant_designs.styles.v#{version}.desc")
  end

  def title
    I18n.t("custom.voice_assistant_designs.title")
  end

  def tagline
    I18n.t("custom.voice_assistant_designs.tagline")
  end

  def open_label
    I18n.t("custom.voice_assistant_designs.open")
  end

  def ready_label
    I18n.t("custom.voice_assistant_designs.ready")
  end

  def starting_label
    I18n.t("custom.voice_assistant_designs.starting")
  end

  def listening_label
    I18n.t("custom.voice_assistant_designs.listening")
  end

  def muted_label
    I18n.t("custom.voice_assistant_designs.muted")
  end

  def mic_start_label
    I18n.t("custom.voice_assistant_designs.mic_start")
  end

  def mic_stop_label
    I18n.t("custom.voice_assistant_designs.mic_stop")
  end

  def mic_unmute_label
    I18n.t("custom.voice_assistant_designs.mic_unmute")
  end

  def stop_label
    I18n.t("custom.voice_assistant_designs.stop")
  end

  def close_label
    I18n.t("custom.voice_assistant_designs.close")
  end
end
