module ProjektPhaseSettingsHelper
  def projekt_phase_feature?(projekt_phase, feature_key)
    return false unless projekt_phase

    projekt_phase.feature?(feature_key)
  end

  def projekt_phase_option(projekt_phase, option_key)
    projekt_phase.option(option_key)
  end

  def show_phase_evaluation_in_footer?(projekt_phase)
    footer_evaluation_tab_visible?(projekt_phase, "stats") ||
      footer_evaluation_tab_visible?(projekt_phase, "ai")
  end

  def footer_phase_evaluation_completed?(projekt_phase)
    evaluation = projekt_phase.projekt_phase_evaluation

    evaluation.present? && evaluation.completed?
  end

  def footer_render_frozen_evaluation?(projekt_phase)
    evaluation = projekt_phase.projekt_phase_evaluation
    return false if evaluation.blank?
    return true if footer_admin_or_projekt_manager?

    evaluation.completed?
  end

  def footer_evaluation_tab_visible?(projekt_phase, tab)
    return false if !can?(:read_stats, projekt_phase)
    return false if !footer_evaluation_tab_has_content?(projekt_phase, tab)

    footer_evaluation_tab_public_visible?(projekt_phase, tab)
  end

  def footer_evaluation_tab_public_visible?(projekt_phase, tab)
    return false if !footer_evaluation_tab_has_content?(projekt_phase, tab)

    if footer_phase_evaluation_completed?(projekt_phase)
      footer_visible_evaluation_tabs(projekt_phase).include?(tab)
    elsif tab == "ai"
      projekt_phase.feature?("general.public_ai_stats")
    else
      projekt_phase.feature?("general.public_kpi_stats")
    end
  end

  def footer_evaluation_tab_has_content?(projekt_phase, tab)
    return true if footer_phase_evaluation_completed?(projekt_phase)

    if tab == "ai"
      footer_live_ai_phase?(projekt_phase)
    else
      footer_live_stats_phase?(projekt_phase)
    end
  end

  def footer_live_stats_phase?(projekt_phase)
    projekt_phase.is_a?(ProjektPhase::ProposalPhase) ||
      projekt_phase.is_a?(ProjektPhase::BudgetPhase)
  end

  def footer_live_ai_phase?(projekt_phase)
    footer_live_stats_phase?(projekt_phase) ||
      projekt_phase.is_a?(ProjektPhase::CommentPhase)
  end

  def footer_evaluation_tab_disabled?(projekt_phase, tab)
    return false if tab != "ai"
    return false if footer_phase_evaluation_completed?(projekt_phase)

    !Ai::Settings.ai_available?
  end

  def footer_admin_or_projekt_manager?
    current_user&.administrator? || current_user&.projekt_manager?
  end

  def footer_visible_evaluation_tabs(projekt_phase)
    visibility = projekt_phase.projekt_phase_evaluation_visibility
    return [] if visibility.blank?

    visible = visibility.visible_sections
    ai_keys = Adm::Projekts::EvaluationHelper::EVALUATION_AI_SECTIONS

    tabs = []
    tabs << "stats" if visible.any? { |key| !ai_keys.include?(key) }
    tabs << "ai" if visible.any? { |key| ai_keys.include?(key) || key == "kpis" }

    tabs
  end
end
