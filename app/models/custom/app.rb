class App < ApplicationRecord
  CODENAMES = [
    VOICE_ASSISTANT_CODENAME = "voice_assistant"
  ]

  APP_CODENAME_FOR_PROPOSAL_SETTINGS = {
    ProjektPhaseSetting::VOICE_ASSISTANT_SETTING => App::VOICE_ASSISTANT_CODENAME
  }

  enum status: [:inactive, :waiting_for_activation, :active], _default: :inactive

  validates :codename, presence: true, inclusion: { in: CODENAMES }

  def self.app_for_proposal_phase_setting(setting_key)
    codename = APP_CODENAME_FOR_PROPOSAL_SETTINGS[setting_key]

    return if codename.blank?

    App.find_or_create_by(codename: codename)
  end
end
