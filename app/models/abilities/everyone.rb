module Abilities
  class Everyone
    include CanCan::Ability

    def initialize(user)
      can [:read, :map], Debate
      can [:read, :map, :summary, :share, :json_data], Proposal
      can :read, Comment
      can :read, Poll
      can :results, Poll, id: Poll.expired.results_enabled.not_budget.ids
      can :stats, Poll, id: Poll.expired.stats_enabled.not_budget.ids
      can :read, Poll::Question
      can [:read, :refresh_activities], User
      can [:read, :welcome], Budget
      can [:read], Budget
      can [:read], Budget::Group
      can [:read, :print, :json_data], Budget::Investment
      can :read_results, Budget, id: Budget.finished.results_enabled.ids
      can :read_stats, Budget, id: Budget.finished.stats_enabled.ids
      can :read_executions, Budget, phase: "finished"
      can :new, DirectMessage
      can [:read, :debate, :draft_publication, :allegations, :result_publication,
           :proposals, :milestones], Legislation::Process, published: true
      can :summary, Legislation::Process,
          id: Legislation::Process.past.published.where(result_publication_enabled: true).ids
      can [:read, :changes, :go_to_version], Legislation::DraftVersion
      can [:read], Legislation::Question
      can [:read, :map, :share], Legislation::Proposal
      can [:search, :comments, :read, :create, :new_comment], Legislation::Annotation
      if Setting['extended_feature.general.elasticsearch']
        can [:read], Search
      end
      can [:read], ProjektQuestion
      can [:read, :create], ProjektQuestionAnswer

      can [:read, :help], ::SDG::Goal
      can :read, ::SDG::Phase

      can [:index, :json_data], DeficiencyReport
      can [:show], DeficiencyReport do |report|
        report.in? DeficiencyReport.admin_accepted(user)
      end

      can :toggle_subscription, ProjektSubscription
      can :toggle_subscription, ProjektPhase

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
      end

      can :read_stats, Budget::Investment do |investment|
        can? :read_stats, investment.budget
      end
    end
  end
end
