module AdmHelper
  include Pagy::Frontend

  def human_boolean(value)
    t("shared.#{value == true}")
  end

  def restriction_label_for(projekt_phase)
    restrictions = []
    restrictions << I18n.t("adm.projekts.phases.restrictions.user_status.#{projekt_phase.user_status}") if projekt_phase.user_status.present?
    restrictions << projekt_phase.geozone_restrictions_formatted if projekt_phase.geozone_restrictions.any?
    restrictions << projekt_phase.age_restriction_formatted if projekt_phase.age_restriction.present?
    restrictions.compact_blank.join(", ").presence || "-"
  end

  def projekt_phase_table_actions(projekt_phase)
    projekt_phase.admin_nav_bar_items.map do |action|
      {
        label: I18n.t("adm.projekts.phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekts_phase_path", projekt_phase)
      }
    end
  end

  def projekt_phase_tabs(projekt_phase, current_action: nil)
    current_action ||= action_name

    projekt_phase.admin_nav_bar_items.map do |action|
      {
        label: I18n.t("adm.projekts.phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekts_phase_path", projekt_phase),
        current: current_action == action
      }
    end
  end

  def idea_tabs(idea, current_action: nil)
    current_action ||= action_name

    %w[show administer audits].map do |action|
      {
        label: I18n.t("adm.ideas.ideas.tabs.#{action}"),
        url: send("#{action == 'show' ? '' : "#{action}_"}adm_ideas_idea_path", idea),
        current: current_action == action
      }
    end
  end

  def deficiency_report_tabs(deficiency_report, current_action: nil)
    current_action ||= action_name

    tabs = %w[show administer audits].map do |action|
      {
        label: I18n.t("adm.deficiency_reports.deficiency_reports.tabs.#{action}"),
        url: send("#{action == 'show' ? '' : "#{action}_"}adm_deficiency_reports_deficiency_report_path", deficiency_report),
        current: current_action == action
      }
    end

    if deficiency_report.feedback_form.present?
      tabs << {
        label: I18n.t("adm.deficiency_reports.deficiency_reports.tabs.feedback_form"),
        url: feedback_form_adm_deficiency_reports_deficiency_report_path(deficiency_report),
        current: current_action == "feedback_form"
      }
    end

    tabs
  end

  def overview_page_tabs(current_action: nil)
    current_action ||= action_name

    %w[navigation footer].map do |action|
      {
        label: I18n.t("adm.projekts.overview_page.tabs.#{action}"),
        url: send("#{action}_adm_projekts_overview_page_path"),
        current: current_action == action
      }
    end
  end

  def projekt_tabs(projekt, current_action: nil)
    current_action ||= action_name

    %w[details visibility projekt_managers map phases].map do |action|
      {
        label: I18n.t("adm.projekts.projekts.tabs.#{action}"),
        url: send("#{action}_adm_projekts_projekt_path", projekt),
        current: current_action == action
      }
    end
  end

  def moderation_status(resource)
    if resource.hidden?
      t("shared.moderation_statuses.hidden")
    elsif resource.ignored_flag?
      t("shared.moderation_statuses.ignored")
    elsif resource.flags_count > 0
      t("shared.moderation_statuses.flagged")
    end
  end
end
