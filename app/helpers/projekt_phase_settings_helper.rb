module ProjektPhaseSettingsHelper
  def projekt_phase_feature?(projekt_phase, feature_key)
    return false unless projekt_phase

    projekt_phase.feature?(feature_key)
  end

  def projekt_phase_option(projekt_phase, option_key)
    projekt_phase.option(option_key)
  end

  def form_attached_image_visible?(resource)
    return resource.respond_to?(:image) if resource.projekt_phase.blank?

    resource.projekt_phase.feature?("form.allow_attached_image")
  end

  def show_phase_evaluation_in_footer?(projekt_phase)
    evaluation = projekt_phase.projekt_phase_evaluation
    return false if evaluation.blank?
    return false if !evaluation.completed?

    if current_user&.administrator? || current_user&.projekt_manager?
      return true
    end

    visibility = projekt_phase.projekt_phase_evaluation_visibility
    visibility.present? && visibility.any_visible?
  end
end
