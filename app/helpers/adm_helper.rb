module AdmHelper
  include Pagy::Frontend

  def human_boolean(value)
    t("shared.#{value == true}")
  end

  def pretty_json(value)
    JSON.pretty_generate(value)
  rescue JSON::GeneratorError, TypeError
    value.to_json
  end

  def format_runtime_ms(milliseconds)
    return "—" if milliseconds.blank?

    "#{number_with_delimiter(milliseconds.round(1))} ms"
  end

  def http_status_label(status)
    reason = Rack::Utils::HTTP_STATUS_CODES[status]
    reason ? "#{status} #{reason}" : status.to_s
  end

  def http_status_explanation(status)
    I18n.t("adm.api_request_logs.status_explanations.#{status}", default: nil)
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
    "formular_follow_up_emails" => "forward_to_inbox",
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
    "email_templates" => "mail",
    "mitmachbox_survey" => "ballot",
    "mitmachbox_deployments" => "devices",
    "mitmachbox_results" => "bar_chart"
  }.freeze

  PHASE_MODERATION_ACTIONS = %w[proposals comments budget_investments].freeze

  def projekt_phase_table_actions(projekt_phase)
    visible_phase_actions(projekt_phase).map do |action|
      {
        label: I18n.t("adm.projekts.phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekts_phase_path", projekt_phase),
        icon: PHASE_ACTION_ICONS[action]
      }
    end
  end

  def projekt_phase_tabs(projekt_phase, current_action: nil)
    current_action ||= action_name

    visible_phase_actions(projekt_phase).map do |action|
      {
        label: I18n.t("adm.projekts.phases.projekt_phase.#{action}"),
        url: send("#{action}_adm_projekts_phase_path", projekt_phase),
        current: current_action == action
      }
    end
  end

  def visible_phase_actions(projekt_phase)
    actions = projekt_phase.admin_nav_bar_items
    return actions if policy([:adm, :projekts, projekt_phase.projekt]).update?

    actions & PHASE_MODERATION_ACTIONS
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

  def projekt_event_tabs(projekt_phase, projekt_event)
    [
      {
        label: I18n.t("adm.projekts.projekt_events.tabs.show"),
        url: adm_projekts_phase_projekt_event_path(projekt_phase, projekt_event),
        current: controller_path == "adm/projekts/projekt_events" && action_name.in?(%w[show edit update])
      },
      {
        label: I18n.t("adm.projekts.projekt_events.tabs.registrations"),
        url: adm_projekts_phase_projekt_event_registrations_path(projekt_phase, projekt_event),
        current: controller_path == "adm/projekts/projekt_event_registrations"
      }
    ]
  end

  def deficiency_report_tabs(deficiency_report, current_action: nil)
    current_action ||= action_name

    tabs = %w[show audits].map do |action|
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

  def overview_pages_tabs(current_action: nil)
    current_action ||= action_name

    %w[projekt others].map do |action|
      {
        label: I18n.t("adm.overview_pages.tabs.#{action}"),
        url: send("#{action}_adm_overview_pages_path"),
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
