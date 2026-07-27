module ProjektPhasesHelper
  SUBCONTROLLER_NAV_ACTIONS = %w[ai_user_flow].freeze

  def projekt_phase_navbar_link(action)
    class_name = ["static-subnav-link", static_subnav_link_current?(action)].reject(&:blank?).join(" ")
    path =
      if SUBCONTROLLER_NAV_ACTIONS.include?(action)
        ai_user_flow_adm_projekts_phase_path(params[:id])
      else
        url_for(controller: "/adm/projekts/phases", action:, id: params[:id], only_path: true)
      end

    link_to path, class: class_name do
      t("custom.admin.projekt_phases.nav_bar.#{action}")
    end
  end

  def link_to_footer_tab(projekt_phase)
  end

  def browse_mode_in_projekt_footer_tab?(projekt_phase)
    return false unless projekt_phase_feature?(projekt_phase, "general.browse_mode_in_phase_footer")

    if params[:proposal_view_mode].blank?
      projekt_phase_feature?(projekt_phase, "general.browse_mode_in_phase_footer_by_default")
    else
      params[:proposal_view_mode] == "browse"
    end
  end

  def admin_projekt_phase_resources_link(projekt_phase)
    case projekt_phase
    when ProjektPhase::QuestionPhase
      link_to projekt_questions_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.question_phase")
      end

    when ProjektPhase::VotingPhase
      if Adm::Projekts::ProjektPhasePolicy.new(current_user, projekt_phase).update?
        link_to poll_questions_adm_projekts_phase_path(projekt_phase), target: "_blank", class: "resources-link" do
          t("custom.admin.projekts.edit.projekt_phases_tab.link.voting_phase")
        end
      end

    when ProjektPhase::BudgetPhase
      link_to budget_investments_adm_projekts_phase_path(projekt_phase), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.budget_phase")
      end

    when ProjektPhase::LegislationPhase
      link_to legislation_process_draft_versions_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.legislation_phase")
      end

    when ProjektPhase::ArgumentPhase
      link_to projekt_arguments_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.argument_phase")
      end

    when ProjektPhase::ProjektNotificationPhase
      link_to projekt_notifications_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.notification_phase")
      end

    when ProjektPhase::MilestonePhase
      link_to milestones_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.milestone_phase")
      end

    when ProjektPhase::EventPhase
      link_to projekt_events_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.event_phase")
      end

    when ProjektPhase::LivestreamPhase
      link_to projekt_livestreams_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.livestream_phase")
      end

    when ProjektPhase::NewsfeedPhase
      link_to general_settings_adm_projekts_phase_path(projekt_phase), target: "_blank",
class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.newsfeed_phase")
      end

    end
  end

  def phase_icon_class(phase)
    case phase
    when ProjektPhase::CommentPhase
      "fa-comment-dots"
    when ProjektPhase::DebatePhase
      "fa-comments"
    when ProjektPhase::ProposalPhase
      "fa-lightbulb"
    when ProjektPhase::QuestionPhase
      "fa-poll-h"
    when ProjektPhase::BudgetPhase
      "fa-euro-sign"
    when ProjektPhase::VotingPhase
      "fa-vote-yea"
    when ProjektPhase::LegislationPhase
      "fa-file-word"
    when ProjektPhase::ArgumentPhase
      "fa-user-tie"
    when ProjektPhase::NewsfeedPhase
      "fa-newspaper"
    when ProjektPhase::MilestonePhase
      "fa-tasks"
    when ProjektPhase::EventPhase
      "fa-calendar-alt"
    when ProjektPhase::LivestreamPhase
      "fa-video"
    when ProjektPhase::ProjektNotificationPhase
      "fa-bell"
    when ProjektPhase::FormularPhase
      "fa-file-alt"
    when ProjektPhase::IframePhase
      "fa-laptop-code"
    when ProjektPhase::PointOfInterestPhase
      "fa-map-pin"
    end
  end

  def projekt_phase_view_permission_problem_message(permission_problem_key, projekt_phase)
    return nil if permission_problem_key.blank?

    sanitize(t("custom.projekt_phases.permission_problem.#{projekt_phase.resources_name}.#{permission_problem_key}",
             sign_in: link_to_signin,
             sign_up: link_to_signup,
             guest_sign_in: link_to_guest_signin,
             enter_missing_user_data: link_to_enter_missing_user_data,
             verify: link_to_verify_account,
             city: Setting["org_name"],
             geozones: projekt_phase.geozone_restrictions_formatted,
             age_restriction: projekt_phase.age_restriction_formatted,
             restricted_streets: projekt_phase.street_restrictions_formatted,
             individual_group_values: projekt_phase.individual_group_value_restriction_formatted
            ))
  end

  def phase_user_status_restriction_name(projekt_phase)
    content_tag :span, class: "geo-restriction-icon" do
      t("custom.admin.projekt_phases.restrictions.user_status.#{projekt_phase.user_status}")
    end
  end

  def phase_geo_restriction_name(projekt_phase)
    return if projekt_phase.geozone_restricted.blank? || projekt_phase.geozone_restricted == "no_restriction"

    extra_info = if projekt_phase.geozone_restricted == "only_geozones"
                   projekt_phase.registered_address_districts.pluck(:name).join(", ")
                 elsif projekt_phase.geozone_restricted == "only_streets"
                   projekt_phase.registered_address_streets.pluck(:name).join(", ")
                 end

    content_tag :span, class: "geo-restriction-icon" do
      [
        t("custom.admin.projekt_phases.restrictions.geo_restrictions.#{projekt_phase.geozone_restricted}"),
        extra_info
      ].compact.join(": ").html_safe
    end
  end

  def phase_extended_geozone_restriction_name(projekt_phase)
    return if projekt_phase.registered_address_grouping_restriction.blank? ||
              projekt_phase.registered_address_grouping_restriction == "no_restriction"

    content_tag :span, class: "geo-restriction-icon" do
      projekt_phase.registered_address_grouping_restriction_formatted
    end
  end

  def phase_age_restriction_name(projekt_phase)
    return if projekt_phase.age_restriction.blank?

    content_tag :span, class: "age-restriction-icon" do
      projekt_phase.age_restriction.name
    end
  end

  def phase_individual_group_value_restriction_name(projekt_phase)
    return if projekt_phase.individual_group_values.blank?

    content_tag :span, class: "geo-restriction-icon" do
      projekt_phase.individual_group_values.group_by(&:individual_group).map do |individual_group, values|
        "#{individual_group.name}: #{values.pluck(:name).join(", ")}"
      end.join("; ")
    end
  end
end
