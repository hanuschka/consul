module Abilities
  class Everyone
    include CanCan::Ability

    def initialize(user)
      can [:read, :map], Debate
      can [:read, :map, :summary, :share, :json_data], Proposal
      can :read, Comment
      can :read, Poll
      can :results, Poll do |poll|
        poll.budget_id.nil? &&
          poll.projekt_phase.present? &&
          poll.projekt_phase.evaluation_tab_publicly_visible?("stats")
      end
      can :stats, Poll do |poll|
        poll.budget_id.nil? &&
          poll.projekt_phase.present? &&
          poll.projekt_phase.evaluation_tab_publicly_visible?("poll_stats")
      end
      can :ai_analysis, Poll,
          budget_id: nil,
          projekt_phase: { settings: { key: "feature.general.public_ai_stats", value: "active" } }
      can :read, Poll::Question
      can [:read, :refresh_activities], User
      can [:read, :welcome], Budget
      can [:read], Budget
      can [:read], Budget::Group
      can [:read, :print, :json_data], Budget::Investment
      can :read_results, Budget do |budget|
        budget.finished? && budget.results_enabled?
      end

      can :read_stats, Budget do |budget|
        budget.accepting_or_later? && budget.stats_enabled?
      end

      can :read_executions, Budget do |budget|
        budget.finished?
      end
      can :new, DirectMessage
      can [:read, :debate, :draft_publication, :allegations, :result_publication,
           :proposals, :milestones], Legislation::Process, published: true
      can :summary, Legislation::Process,
          published: true, result_publication_enabled: true, end_date: (...Date.current)
      can [:read, :changes, :go_to_version], Legislation::DraftVersion
      can [:read], Legislation::Question
      can [:read, :map, :share], Legislation::Proposal
      can [:search, :comments, :read, :create, :new_comment], Legislation::Annotation
      can [:read], ProjektQuestion
      can [:read, :create], ProjektQuestionAnswer

      can [:read, :help], ::SDG::Goal
      can :read, ::SDG::Phase

      can [:json_data], DeficiencyReport
      if Setting["deficiency_reports.admin_acceptance_required"].present?
        can [:index, :show], DeficiencyReport, admin_accepted: true
      else
        can [:index, :show], DeficiencyReport
      end

      can :toggle_subscription, ProjektSubscription do |subscription|
        subscription.user == user
      end
      can :toggle_subscription, ProjektPhase

      can :show, Community do |community|
        projekt_phase = community.communitable&.projekt_phase

        projekt_phase.present? &&
          projekt_phase.feature?("resource.show_community_button_in_proposal_sidebar") &&
          community.topics.any?
      end

      if user&.guest?
        can [:create, :destroy], DirectUpload

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

        can [:create, :suggest, :vote, :unvote], Proposal
        can [:edit, :update, :retire, :retire_form], Proposal, author_id: user.id
        can [:create, :suggest, :vote], Debate
        can [:edit, :update], Debate, author_id: user.id

        can [:create, :vote], Comment do |comment|
          comment.commentable.comments_allowed?(user)
        end

        can [:new, :create], Budget::Investment do |investment|
          projekt_phase = investment.budget.projekt_phase

          projekt_phase.present? &&
            investment.budget.current_phase&.kind == "accepting" &&
            projekt_phase.selectable_by_users?
        end

        can [:create, :destroy], ActsAsVotable::Vote,
            votable_type: "Budget::Investment",
            voter_id: user.id

        can [:show, :create], Budget::Ballot do |ballot|
          ballot.budget.balloting?
        end

        can [:create, :destroy], Budget::Ballot::Line do |line|
          line.budget.balloting?
        end

        can [:create, :destroy], ActsAsVotable::Vote,
            votable_type: "Budget::Investment",
            voter_id: user.id

        can [:show, :create], Budget::Ballot, budget: { id: Budget.balloting.pluck(:id) }
        can [:create, :destroy], Budget::Ballot::Line, budget: { id: Budget.balloting.pluck(:id) }

        can [:create, :update], FormularAnswer do |formular_answer|
          formular_answer.formular.projekt_phase.permission_problem(user).blank?
        end

        can [:create], ProjektPointOfInterestPin do |pin|
          pin.projekt_phase.permission_problem(user).blank?
        end
      end

      can :read_stats, Budget::Investment do |investment|
        can? :read_stats, investment.budget
      end

      can :read_stats, ProjektPhase

      can [:index, :show, :json_data], Idea, admin_accepted_at: (Time.zone.at(0)..)
    end
  end
end
