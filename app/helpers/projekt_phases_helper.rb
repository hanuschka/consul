module ProjektPhasesHelper
  def projekt_phase_navbar_link(action)
    class_name = ["static-subnav-link", static_subnav_link_current?(action)].reject(&:blank?).join(" ")

    link_to namespace_projekt_phase_path(action: action), class: class_name do
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
    projekt = projekt_phase.projekt

    case projekt_phase
    when ProjektPhase::QuestionPhase
      link_to edit_admin_projekt_path(projekt, anchor: "tab-projekt-questions"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.question_phase")
      end

    when ProjektPhase::VotingPhase
      link_to admin_polls_path, target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.voting_phase")
      end

    when ProjektPhase::VotingPhase
      link_to admin_budgets_path, target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.budget_phase")
      end

    when ProjektPhase::LegislationPhase
      link_to admin_legislation_processes_path(anchor: "tab-projekt-questions"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.legislation_phase")
      end

    when ProjektPhase::ArgumentPhase
      link_to edit_admin_projekt_path(projekt, anchor: "tab-projekt-arguments"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.argument_phase")
      end

    when ProjektPhase::ProjektNotificationPhase
      link_to edit_admin_projekt_path(projekt, anchor: "tab-projekt-notifications"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.notification_phase")
      end

    when ProjektPhase::MilestonePhase
      link_to edit_admin_projekt_path(projekt, anchor: "tab-projekt-milestones"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.milestone_phase")
      end

    when ProjektPhase::EventPhase
      link_to edit_admin_projekt_path(projekt, anchor: "tab-projekt-events"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.event_phase")
      end

    when ProjektPhase::LivestreamPhase
      link_to edit_admin_projekt_path(projekt, anchor:   "tab-projekt-livestreams"), target: "_blank", class: "resources-link" do
        t("custom.admin.projekts.edit.projekt_phases_tab.link.livestream_phase")
      end

    when ProjektPhase::NewsfeedPhase
      link_to edit_admin_projekt_path(projekt, anchor: "t  ab-projekt-newsfeeds"), target: "_blank", class: "resources-link" do
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
    end
  end
end
