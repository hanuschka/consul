module ProjektPhaseSettingsHelper
  def projekt_phase_feature?(projekt_phase, feature_key)
    return false unless projekt_phase

    projekt_phase.feature?(feature_key)
  end

  def projekt_phase_pro_feature?(projekt_phase, feature_key)
    app = App.app_for_proposal_phase_setting("feature.#{feature_key}")

    projekt_phase_feature?(projekt_phase, feature_key) && app&.active?
  end

  def projekt_phase_option(projekt_phase, option_key)
    projekt_phase.option(option_key)
  end
end
