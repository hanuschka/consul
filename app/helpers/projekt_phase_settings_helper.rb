module ProjektPhaseSettingsHelper
  FOOTER_LIVE_STATS_TTL = 5.minutes
  FOOTER_LIVE_STATS_ADMIN_TTL = 1.minute

  def footer_live_stats_cache_bucket
    Time.current.to_i / FOOTER_LIVE_STATS_TTL.to_i
  end

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
    footer_evaluation_tab_visible?(projekt_phase, "stats") ||
      footer_evaluation_tab_visible?(projekt_phase, "ai")
  end

  def footer_phase_evaluation_completed?(projekt_phase)
    projekt_phase.evaluation_completed?
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

  def footer_evaluation_tab_available?(projekt_phase, tab)
    return false if !can?(:read_stats, projekt_phase)
    return false if !footer_evaluation_tab_has_content?(projekt_phase, tab)

    footer_evaluation_tab_public_visible?(projekt_phase, tab) ||
      can?(:edit, projekt_phase.projekt)
  end

  def footer_evaluation_tab_public_visible?(projekt_phase, tab)
    return false if !footer_evaluation_tab_has_content?(projekt_phase, tab)

    projekt_phase.evaluation_tab_publicly_visible?(tab)
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
    return false if Ai::Settings.ai_available?

    !footer_frozen_ai_content?(projekt_phase)
  end

  def footer_frozen_ai_content?(projekt_phase)
    return false if !footer_phase_evaluation_completed?(projekt_phase)

    projekt_phase.projekt_phase_evaluation&.ai_content? || false
  end

  def footer_admin_or_projekt_manager?
    current_user&.administrator? || current_user&.projekt_manager?
  end

  def footer_evaluation_tab_label(projekt_phase, tab)
    voting_phase = projekt_phase.is_a?(ProjektPhase::VotingPhase)

    case tab.to_s
    when "poll_stats"
      t("adm.projekts.projekts.evaluation.view_tabs.poll_stats")
    when "ai"
      if voting_phase
        t("adm.projekts.projekts.evaluation.view_tabs.ai")
      else
        t("custom.projekt_phases.subnav.ai_evaluation")
      end
    else
      if voting_phase
        t("adm.projekts.projekts.evaluation.view_tabs.stats")
      else
        t("custom.projekt_phases.subnav.evaluation")
      end
    end
  end

  def footer_visible_evaluation_tabs(projekt_phase)
    projekt_phase.publicly_visible_evaluation_tabs
  end

  # hidden: true/false wraps the content in an explanatory rich-tooltip that
  # is active only while hidden; nil renders the content bare (viewer cannot
  # toggle the tab, so no tooltip belongs on it).
  def hidden_from_public_tooltip(hidden, content)
    return content if hidden.nil?

    attributes = { instant: "", delay: 1500, "trigger-only": "", shadow: "heavy" }
    attributes[:disabled] = "" if !hidden

    content_tag("rich-tooltip", attributes) do
      content +
        content_tag(:template, t("custom.projekt_phases.footer_evaluation.tab_hidden_from_public_tooltip"))
    end
  end
end
