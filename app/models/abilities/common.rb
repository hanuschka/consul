module Abilities
  class Common
    include CanCan::Ability

    def initialize(user)
      merge Abilities::Everyone.new(user)

      can [:read, :update, :refresh_activities,
           :edit_username, :update_username, :edit_details, :update_details], User, id: user.id

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

      can [:answer, :unanswer, :update_open_answer], Poll::Question do |question|
        question.answerable_by?(user)
      end

      can :destroy, Poll::Answer do |answer|
        answer.author == user && answer.question.answerable_by?(user)
      end

      # can :create, Budget::Investment,               budget: { phase: "accepting" }
      can :edit, Budget::Investment,                 budget: { id: Budget.accepting.pluck(:id) }, author_id: user.id
      can :update, Budget::Investment,               budget: { id: Budget.accepting.pluck(:id) }, author_id: user.id
      can :suggest, Budget::Investment,              budget: { id: Budget.accepting.pluck(:id) }
      can :destroy, Budget::Investment,              budget: { id: (Budget.accepting.pluck(:id) + Budget.reviewing.pluck(:id)) }, author_id: user.id
      can [:create, :destroy], ActsAsVotable::Vote,
        voter_id: user.id,
        votable_type: "Budget::Investment",
        votable: { budget: { id: Budget.selecting.pluck(:id) }}

      can [:show, :create], Budget::Ballot,          budget: { id: (Budget.balloting.pluck(:id) + ((user.administrator? || user.poll_officer?) ?  Budget.reviewing_ballots.pluck(:id) : [] )) }
      can [:create, :destroy], Budget::Ballot::Line, budget: { id: (Budget.balloting.pluck(:id) + ((user.administrator? || user.poll_officer?) ?  Budget.reviewing_ballots.pluck(:id) : [] )) }

      if user.level_two_or_three_verified?
        can :vote, Legislation::Proposal
        can :create, Legislation::Answer

        can :create, DirectMessage
        can :show, DirectMessage, sender_id: user.id
      end

      can [:create, :show, :edit, :update, :destroy], ProposalNotification, proposal: { author_id: user.id }

      can [:create], Topic
      can [:update, :destroy], Topic, author_id: user.id

      can :disable_recommendations, [Debate, Proposal]

      can :select, ProjektPhase do |projekt_phase|
        projekt_phase.selectable_by?(user)
      end

      can [:index, :show, :vote, :json_data, :suggest], DeficiencyReport,
        id: DeficiencyReport.admin_accepted.or(DeficiencyReport.by_author(user)).ids
      can [:create], DeficiencyReport
      can :destroy, DeficiencyReport do |dr|
        dr.author_id == user.id &&
          dr.official_answer.blank?
      end

      can :create, Budget::Investment do |investment|
        projekt_phase = investment.budget.projekt_phase

        investment.budget.current_phase.kind == "accepting" &&
          (projekt_phase.selectable_by_users? || user.has_pm_permission_to?("manage", projekt_phase.projekt))
      end

      can [:create, :vote], Comment do |comment|
        !user.organization? &&
        comment.commentable.comments_allowed?(user)
      end

      # extending to regular users
      can :access, :ckeditor
      can :manage, Ckeditor::Picture

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

      can [:create, :update], FormularAnswer

      can :show, Community do |community|
        return false unless community.communitable.present?
        return false unless community.communitable.projekt_phase.present?

        projekt_phase = community.communitable.projekt_phase

        projekt_phase.feature?("resource.show_community_button_in_proposal_sidebar") &&
          (community.communitable.projekt_phase.permission_problem(user).blank? || community.topics.any?)
      end

      can :create_topic, Community do |community|
        return false unless community.communitable.present?
        return false unless community.communitable.projekt_phase.present?

        projekt_phase = community.communitable.projekt_phase

        projekt_phase.feature?("resource.show_community_button_in_proposal_sidebar") &&
          community.communitable.projekt_phase.permission_problem(user).blank?
      end
    end
  end
end
