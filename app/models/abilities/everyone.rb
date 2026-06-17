module Abilities
  class Everyone
    include CanCan::Ability

    def initialize(user)
      can [:read, :map], Debate
      can [:read, :map, :summary, :share, :json_data], Proposal
      can :read, Comment
      can :read, Poll
      can :results, Poll, id: Poll.with_phase_feature("resource.results_enabled").not_budget.ids
      can :stats, Poll, id: Poll.with_phase_feature("resource.stats_enabled").not_budget.ids
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
          id: Legislation::Process.past.published.where(result_publication_enabled: true).ids
      can [:read, :changes, :go_to_version], Legislation::DraftVersion
      can [:read], Legislation::Question
      can [:read, :map, :share], Legislation::Proposal
      can [:search, :comments, :read, :create, :new_comment], Legislation::Annotation
      can [:read], ProjektQuestion
      can [:read, :create], ProjektQuestionAnswer

      can [:read, :help], ::SDG::Goal
      can :read, ::SDG::Phase

      can [:json_data], DeficiencyReport
      can [:index, :show], DeficiencyReport, id: DeficiencyReport.admin_accepted.ids

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

        can [:answer, :unanswer, :update_open_answer], Poll::Question do |question|
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

      can [:index, :show, :json_data], Idea, id: Idea.accepted.ids
    end
  end
end
