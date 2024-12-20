module Abilities
  class Everyone
    include CanCan::Ability

    def initialize(user)
      can [:read, :map], Debate
      can [:read, :map, :summary, :share, :json_data], Proposal
      can :read, Comment
      can :read, Poll
      can :results, Poll, id: Poll.expired.with_phase_feature("resource.results_enabled").not_budget.ids
      can :stats, Poll, id: Poll.expired.with_phase_feature("resource.stats_enabled").not_budget.ids
      can :read, Poll::Question
      can [:read, :refresh_activities], User
      can [:read, :welcome], Budget
      can [:read], Budget
      can [:read], Budget::Group
      can [:read, :print, :json_data], Budget::Investment
      can :read_results, Budget, id: Budget.where(id: Budget.finished.pluck(:id)).results_enabled.ids
      can :read_stats, Budget, id: (
        Budget.where(id: Budget.finished.pluck(:id)).stats_enabled.ids +
        Budget.where(id: Budget.valuating_or_later.pluck(:id), show_results_after_first_vote: true).ids
      ).uniq
      can :read_executions, Budget, id: Budget.finished.pluck(:id)
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

      can :toggle_subscription, ProjektSubscription
      can :toggle_subscription, ProjektPhase

      can :show, Community do |community|
        return false unless community.communitable.present?
        return false unless community.communitable.projekt_phase_id.present?

        projekt_phase = community.communitable.projekt_phase

        projekt_phase.feature?("resource.show_community_button_in_proposal_sidebar") && community.topics.any?
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

          investment.budget.current_phase.kind == "accepting" && projekt_phase.selectable_by_users?
        end
      end

      can :read_stats, Budget::Investment do |investment|
        can? :read_stats, investment.budget
      end
    end
  end
end
