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

  PHASE_ACTION_ICONS = {
    "duration" => "schedule",
    "naming" => "label",
    "restrictions" => "lock",
    "general_settings" => "tune",
    "form_author" => "person",
    "user_functions" => "group",
    "proposals" => "lightbulb",
    "comments" => "forum",
    "poll_questions" => "ballot",
    "projekt_labels" => "label",
    "sentiments" => "palette",
    "map" => "map",
    "milestones" => "flag",
    "progress_bars" => "trending_up",
    "budget_phases" => "payments",
    "budget_edit" => "edit",
    "budget_investments" => "savings",
    "formular" => "assignment",
    "formular_answers" => "list_alt",
    "officing_managers" => "badge",
    "officing_manager_audits" => "history",
    "ai_settings" => "smart_toy",
    "ai_user_flow" => "checklist",
    "projekt_notifications" => "notifications",
    "projekt_events" => "event",
    "projekt_livestreams" => "videocam",
    "projekt_questions" => "quiz",
    "projekt_arguments" => "balance",
    "projekt_point_of_interest_categories" => "category",
    "projekt_point_of_interest_pins" => "pin_drop",
    "map_resources_overview" => "layers",
    "legislation_process_draft_versions" => "description",
    "age_ranges_for_stats" => "pie_chart",
    "email_templates" => "mail"
  }.freeze

  def projekt_phase_table_actions(projekt_phase)
    projekt_phase.admin_nav_bar_items.map do |action|
      {
        label: I18n.t("adm.projekts.phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekts_phase_path", projekt_phase),
        icon: PHASE_ACTION_ICONS[action]
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

  def legislation_draft_version_tabs(draft_version, current_action: nil)
    current_action ||= action_name
    phase = draft_version.projekt_phase

    [
      {
        label: I18n.t("adm.projekts.legislation_draft_versions.tabs.edit"),
        url: edit_adm_projekts_phase_legislation_draft_version_path(phase, draft_version),
        current: current_action == "edit"
      },
      {
        label: I18n.t("adm.projekts.legislation_draft_versions.tabs.draft_text"),
        url: draft_text_adm_projekts_phase_legislation_draft_version_path(phase, draft_version),
        current: current_action == "draft_text"
      }
    ]
  end

  def pages_tabs(current_slug: nil)
    current_slug ||= params[:slug]

    %w[privacy conditions impressum].map do |slug|
      {
        label: I18n.t("adm.site_customization.pages.tabs.#{slug}"),
        url: adm_site_customization_edit_page_by_slug_path(slug: slug),
        current: current_slug == slug
      }
    end
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

  def relative_time(datetime)
    return "" if datetime.blank?

    seconds = (Time.current - datetime).to_i

    if seconds < 60
      "gerade eben"
    elsif seconds < 3600
      minutes = seconds / 60
      "vor #{minutes} Min."
    elsif seconds < 86_400
      hours = seconds / 3600
      "vor #{hours} Std."
    elsif seconds < 604_800
      days = seconds / 86_400
      days == 1 ? "vor 1 Tag" : "vor #{days} Tagen"
    else
      l(datetime, format: :datetime)
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
