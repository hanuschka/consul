class App < ApplicationRecord
  CODENAMES = [
    VOICE_ASSISTANT_CODENAME = "voice_assistant"
  ]

  APP_CODENAME_FOR_PROJEKT_PROPOSAL_SETTINGS = {
    "feature.form.voice_assistant" => App::VOICE_ASSISTANT_CODENAME
  }
  APP_CODENAME_FOR_GENERAL_SETTINGS = {
    "deficiency_reports.voice_assistant" => App::VOICE_ASSISTANT_CODENAME
  }

  APP_CODENAME_FOR_SETTINGS = {
    Setting::DEFICIENCY_REPORT_VOICE_ASSISTANT => App::VOICE_ASSISTANT_CODENAME
  }

  enum status: [:inactive, :waiting_for_activation, :active], _default: :inactive

  validates :codename, presence: true, inclusion: { in: CODENAMES }

  def self.app_for_projekt_phase_setting(projekt_phase, setting_key)
    codename =
      case projekt_phase.type
      when "ProjektPhase::ProposalPhase", "ProjektPhase::BudgetPhase"
        APP_CODENAME_FOR_PROJEKT_PROPOSAL_SETTINGS[setting_key]
      end

    return if codename.blank?

    App.find_or_create_by(codename: codename)
  end

  def self.app_for_general_setting(setting_key)
    codename = APP_CODENAME_FOR_GENERAL_SETTINGS[setting_key]

    return if codename.blank?

    App.find_or_create_by(codename: codename)
  end

  def self.app_for_setting(setting_key)
    codename = APP_CODENAME_FOR_SETTINGS[setting_key]

    return if codename.blank?

    App.find_or_create_by(codename: codename)
  end
end
