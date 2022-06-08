module Abilities
  class Common
    include CanCan::Ability

    def initialize(user)
      merge Abilities::Everyone.new(user)

      can [:read, :update], User, id: user.id

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
      cannot [:edit, :update], Legislation::Proposal do |proposal|
        proposal.editable_by?(user)
      end
      can [:retire_form, :retire], Legislation::Proposal, author_id: user.id

      can :create, Comment
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
        can :vote, Comment
      end

      if user.level_two_or_three_verified?
        can :vote, Proposal, &:published?
        can :unvote, Proposal, &:published?
        can :vote_featured, Proposal

        can :vote, Legislation::Proposal
        can :vote_featured, Legislation::Proposal
        can :create, Legislation::Answer

        # can :create, Budget::Investment,               budget: { phase: "accepting" }
        can :edit, Budget::Investment,                 budget: { phase: "accepting" }, author_id: user.id
        can :update, Budget::Investment,               budget: { phase: "accepting" }, author_id: user.id
        can :suggest, Budget::Investment,              budget: { phase: "accepting" }
        can :destroy, Budget::Investment,              budget: { phase: ["accepting", "reviewing"] }, author_id: user.id
        can [:create, :destroy], ActsAsVotable::Vote,
          voter_id: user.id,
          votable_type: "Budget::Investment",
          votable: { budget: { phase: "selecting" }}

        can [:show, :create], Budget::Ballot,          budget: { phase: "balloting" }
        can [:create, :destroy], Budget::Ballot::Line, budget: { phase: "balloting" }

        can :create, DirectMessage
        can :show, DirectMessage, sender_id: user.id

        can [:answer, :unanswer, :confirm_participation], Poll do |poll|
          poll.answerable_by?(user)
        end
        can [:answer, :unanswer, :update_open_answer], Poll::Question do |question|
          question.answerable_by?(user)
        end
      end

      can [:create, :show], ProposalNotification, proposal: { author_id: user.id }

      can [:create], Topic
      can [:update, :destroy], Topic, author_id: user.id

      can :disable_recommendations, [Debate, Proposal]

      can :select, ProjektPhase do |projekt_phase|
        projekt_phase.selectable_by?(user)
      end

      can [:read, :json_data, :create, :vote], DeficiencyReport

      can :create, Budget::Investment do |investment|
        investment.budget.phase == "accepting" &&
          (
           (ProjektSetting.find_by(projekt: investment.projekt, key: "projekt_feature.budgets.only_admins_create_investment_proposals").value.present? && user.administrator? ) ||
           ProjektSetting.find_by(projekt: investment.projekt, key: "projekt_feature.budgets.only_admins_create_investment_proposals").value.blank?
          )
      end

      # extending to regular users
      can :access, :ckeditor
      can :manage, Ckeditor::Picture
    end
  end
end
