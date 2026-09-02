module Abilities
  class Common
    include CanCan::Ability

    def initialize(user)
      merge Abilities::Everyone.new(user)

      can [:read, :update, :refresh_activities,
           :update_username, :edit_details, :update_details], User, id: user.id

      can :read, Debate
      can :update, Debate do |debate|
        debate.editable_by?(user)
      end

      can :read, Proposal
      can :update, Proposal do |proposal|
        proposal.editable_by?(user)
      end
      can :publish, Proposal do |proposal|
        proposal.draft? && proposal.author.id == user.id && !proposal.retired?
      end
      can :dashboard, Proposal do |proposal|
        proposal.author.id == user.id
      end
      can :manage_polls, Proposal do |proposal|
        proposal.author.id == user.id
      end
      can :manage_mailing, Proposal do |proposal|
        proposal.author.id == user.id
      end
      can :manage_poster, Proposal do |proposal|
        proposal.author.id == user.id
      end

      can :results, Poll do |poll|
        poll.related&.author&.id == user.id
      end

      can [:report, :download_report_section, :download_all_report_sections], Poll do |poll|
        poll.report_visible_for_citizens? && poll.projekt&.visible_for?(user)
      end

      can [:retire_form, :retire], Proposal, author_id: user.id

      can :read, Legislation::Proposal
      can [:retire_form, :retire], Legislation::Proposal, author_id: user.id

      # can :create, Comment
      can :create, Debate
      can [:create, :created], Proposal
      can :create, Legislation::Proposal

      can :hide, Comment, user_id: user.id

      can :suggest, Debate
      can :suggest, Proposal
      can :suggest, Legislation::Proposal
      can :suggest, Tag

      can [:flag, :unflag], Comment
      cannot [:flag, :unflag], Comment, user_id: user.id

      can [:flag, :unflag], Debate
      cannot [:flag, :unflag], Debate, author_id: user.id

      can [:flag, :unflag], Proposal
      cannot [:flag, :unflag], Proposal, author_id: user.id

      can [:flag, :unflag], Legislation::Proposal
      cannot [:flag, :unflag], Legislation::Proposal, author_id: user.id

      can [:flag, :unflag], Budget::Investment
      cannot [:flag, :unflag], Budget::Investment, author_id: user.id

      can [:create, :destroy], Follow, user_id: user.id

      can [:destroy], Document do |document|
        document.documentable&.author_id == user.id
      end

      can [:destroy], Image, imageable: { author_id: user.id }

      can [:create, :destroy], DirectUpload

      unless user.organization?
        can :vote, Debate
        # can :vote, Comment
      end

      can :vote, Proposal, &:published?
      can :unvote, Proposal, &:published?
      can :vote_featured, Proposal

      can [:answer, :unanswer, :confirm_participation], Poll do |poll|
        poll.answerable_by?(user)
      end

      can [:answer, :unanswer, :update_open_answer, :add_map_point, :remove_map_point],
          Poll::Question do |question|
        question.answerable_by?(user)
      end

      can :destroy, Poll::Answer do |answer|
        answer.author == user && answer.question.answerable_by?(user)
      end

      # can :create, Budget::Investment,               budget: { phase: "accepting" }
      can [:edit, :update], Budget::Investment do |investment|
        investment.author_id == user.id &&
          investment.feasibility == "undecided" &&
          investment.budget.accepting?
      end

      can :suggest, Budget::Investment do |investment|
        investment.budget.accepting? || investment.budget.reviewing?
      end

      can :destroy, Budget::Investment do |investment|
        investment.author_id == user.id &&
          (investment.budget.accepting? || investment.budget.reviewing?)
      end

      can [:create, :destroy], ActsAsVotable::Vote do |vote|
        vote.voter_id == user.id &&
          vote.votable_type == "Budget::Investment" &&
          vote.votable.present? &&
          vote.votable.budget.selecting?
      end

      can [:show, :create], Budget::Ballot do |ballot|
        ballot.budget.balloting? ||
          ((user.administrator? || user.officing_manager?) && ballot.budget.reviewing_ballots?)
      end

      can [:create, :destroy], Budget::Ballot::Line do |line|
        line.budget.balloting? ||
          ((user.administrator? || user.officing_manager?) && line.budget.reviewing_ballots?)
      end

      if user.level_two_or_three_verified?
        can :vote, Legislation::Proposal
        can :create, Legislation::Answer

        # can :create, DirectMessage
        # can :show, DirectMessage, sender_id: user.id
      end
      can :create, DirectMessage
      can :show, DirectMessage, sender_id: user.id

      can [:create, :show, :edit, :update, :destroy], ProposalNotification, proposal: { author_id: user.id }

      can [:create], Topic
      can [:update, :destroy], Topic, author_id: user.id

      can :disable_recommendations, [Debate, Proposal]

      can :select, ProjektPhase do |projekt_phase|
        projekt_phase.selectable_by?(user)
      end

      deficiency_report_read_actions = [:index, :show, :vote, :json_data, :suggest]

      if Setting["deficiency_reports.admin_acceptance_required"].present?
        can deficiency_report_read_actions, DeficiencyReport, admin_accepted: true
      else
        can deficiency_report_read_actions, DeficiencyReport
      end

      can deficiency_report_read_actions, DeficiencyReport, author_id: user.id
      can [:create], DeficiencyReport if DeficiencyReport.submissions_open?
      can :destroy, DeficiencyReport do |dr|
        dr.author_id == user.id &&
          dr.official_answer.blank?
      end

      can :create, Budget::Investment do |investment|
        projekt_phase = investment.budget.projekt_phase

        projekt_phase.present? &&
          ((investment.budget.accepting? && projekt_phase.selectable_by_users?) ||
            ((investment.budget.accepting? || investment.budget.reviewing?) &&
              user.has_pm_permission_to?("manage", projekt_phase.projekt)))
      end

      can [:create, :vote], Comment do |comment|
        !user.organization? &&
        comment.commentable.comments_allowed?(user)
      end

      # extending to regular users
      can :access, :ckeditor
      can :create, AdminImage
      can [:update, :destroy], AdminImage do |admin_image|
        admin_image.projekt.present? &&
          user.has_pm_permission_to?("manage", admin_image.projekt)
      end

      can :toggle_subscription, ProjektSubscription do |subscription|
        subscription.user == user
      end

      can :toggle_subscription, ProjektPhaseSubscription do |subscription|
        subscription.user == user
      end

      can :create, RelatedContent
      can :destroy, RelatedContent do |related_content|
        related_content.author_id == user.id
      end

      can [:create, :update], FormularAnswer do |formular_answer|
        formular_answer.formular.projekt_phase.permission_problem(user).blank?
      end

      can :show, Community do |community|
        projekt_phase = community.communitable&.projekt_phase

        projekt_phase.present? &&
          projekt_phase.feature?("resource.show_community_button_in_proposal_sidebar") &&
          (projekt_phase.permission_problem(user).blank? || community.topics.any?)
      end

      can :create_topic, Community do |community|
        projekt_phase = community.communitable&.projekt_phase

        projekt_phase.present? &&
          projekt_phase.feature?("resource.show_community_button_in_proposal_sidebar") &&
          projekt_phase.permission_problem(user).blank?
      end

      idea_read_actions = [:index, :show, :vote, :unvote, :json_data, :suggest]

      can idea_read_actions, Idea, admin_accepted_at: (Time.zone.at(0)..)
      can idea_read_actions, Idea, author_id: user.id
      can [:create], Idea
      can [:create], ProjektPointOfInterestPin do |pin|
        pin.projekt_phase.permission_problem(user).blank?
      end

      can [:create], DeficiencyReport::FeedbackForm do |ff|
        ff.deficiency_report.author_id == user.id
      end
    end
  end
end
