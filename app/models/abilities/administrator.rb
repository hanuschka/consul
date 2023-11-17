module Abilities
  class Administrator
    include CanCan::Ability

    def initialize(user)
      merge Abilities::Moderation.new(user)
      merge Abilities::SDG::Manager.new(user)

      can :restore, Comment
      cannot :restore, Comment, hidden_at: nil

      can :restore, Debate
      cannot :restore, Debate, hidden_at: nil

      can :restore, Proposal
      cannot :restore, Proposal, hidden_at: nil

      can :create, Legislation::Proposal
      can :show, Legislation::Proposal
      can :proposals, ::Legislation::Process

      can :restore, Legislation::Proposal
      cannot :restore, Legislation::Proposal, hidden_at: nil

      can :restore, Budget::Investment
      cannot :restore, Budget::Investment, hidden_at: nil

      can :restore, User
      cannot :restore, User, hidden_at: nil

      can :confirm_hide, Comment
      cannot :confirm_hide, Comment, hidden_at: nil

      can :confirm_hide, Debate
      cannot :confirm_hide, Debate, hidden_at: nil

      can :confirm_hide, Proposal
      cannot :confirm_hide, Proposal, hidden_at: nil

      can :confirm_hide, Legislation::Proposal
      cannot :confirm_hide, Legislation::Proposal, hidden_at: nil

      can :confirm_hide, Budget::Investment
      cannot :confirm_hide, Budget::Investment, hidden_at: nil

      can :confirm_hide, User
      cannot :confirm_hide, User, hidden_at: nil

      can :mark_featured, Debate
      can :unmark_featured, Debate

      can :comment_as_administrator, [Debate, Comment, Proposal, Poll, Poll::Question, Budget::Investment, Projekt,
                                      Legislation::Question, Legislation::Proposal, Legislation::Annotation, Topic, Projekt]

      can [:search, :create, :index, :destroy, :update], ::Administrator
      can [:search, :create, :index, :destroy], ::ProjektManager # custom
      can [:search, :create, :index, :destroy], ::Moderator
      can [:search, :show, :update, :create, :index, :destroy, :summary], ::Valuator
      can [:search, :create, :index, :destroy], ::Manager
      can [:create, :read, :destroy], ::SDG::Manager
      can [:search, :index], ::User

      can :manage, Dashboard::Action

      can [:index, :read, :create, :update, :destroy], Budget
      can :publish, Budget, id: Budget.drafting.ids
      can :calculate_winners, Budget, &:reviewing_ballots?
      can :read_results, Budget do |budget|
        budget.balloting_or_later?
        # budget.balloting_finished? && budget.has_winning_investments?
      end
      can :recalculate_winners, Budget, &:balloting_or_later?

      can [:read, :create, :update, :destroy], Budget::Group
      can [:read, :create, :update, :destroy], Budget::Heading
      can [:hide, :admin_update, :toggle_selection], Budget::Investment
      can [:valuate, :comment_valuation], Budget::Investment
      cannot [:admin_update, :toggle_selection, :valuate, :comment_valuation],
        Budget::Investment, budget: { phase: "finished" }

      can :create, Budget::ValuatorAssignment

      can :read_admin_stats, Budget, &:balloting_or_later?

      can [:search, :update, :create, :index, :destroy], Banner

      can [:index, :create, :update, :destroy], Geozone

      can [:read, :create, :update, :destroy, :add_question, :search_booths, :search_officers, :booth_assignments, :send_notifications], Poll
      can [:read, :create, :update, :destroy, :available], Poll::Booth
      can [:search, :create, :index, :destroy], ::Poll::Officer
      can [:create, :destroy, :manage], ::Poll::BoothAssignment
      can [:create, :destroy], ::Poll::OfficerAssignment

      can :read, Poll::Question
      can [:create], Poll::Question
      can [:update, :destroy], Poll::Question

      can [:read, :order_answer], Poll::Question::Answer
      can [:create, :update, :destroy], Poll::Question::Answer do |answer|
        can?(:update, answer.question)
      end

      can :read, Poll::Question::Answer::Video

      can [:create, :update, :destroy], Poll::Question::Answer::Video do |video|
        can?(:update, video.answer)
      end
      can [:destroy], Image do |image|
        image.imageable_type == "Poll::Question::Answer" && can?(:update, image.imageable)
      end

      can :manage, SiteCustomization::Page
      can :manage, SiteCustomization::Image
      can :manage, SiteCustomization::ContentBlock
      can :manage, Widget::Card

      can :access, :ckeditor
      can :manage, Ckeditor::Picture

      can [:read, :debate, :draft_publication, :allegations, :result_publication,
           :milestones], Legislation::Process
      can [:create, :update, :destroy], Legislation::Process
      can [:manage], ::Legislation::DraftVersion
      can [:manage], ::Legislation::Question
      can [:manage], ::Legislation::Proposal
      cannot :comment_as_moderator, [::Legislation::Question, Legislation::Annotation, ::Legislation::Proposal]

      can [:create], Document
      can [:destroy], Document, documentable_type: "Poll::Question::Answer"
      can [:create, :destroy], DirectUpload

      can [:deliver], Newsletter, hidden_at: nil
      can [:manage], Dashboard::AdministratorTask

      can :manage, LocalCensusRecord
      can [:create, :read], LocalCensusRecords::Import


      #custom
      can :send_letter_verification_code, User
      can :cancel_letter_verification_code, User
      can [:manage], ::DeficiencyReport::Officer
      can [:manage], ::DeficiencyReport::Category
      can [:manage], ::DeficiencyReport::Status
      can [:manage], ::DeficiencyReport::Area
      can [:index, :show, :new, :create, :destroy, :update_status, :update_category, :update_officer, :update_official_answer, :vote, :order_statuses], DeficiencyReport
      can [:approve_official_answer], ::DeficiencyReport do |dr|
        Setting['deficiency_reports.admins_must_approve_officer_answer'].present? &&
          !dr.official_answer_approved? &&
          dr.official_answer.present?
      end

      can [:csv_answers_votes], Poll
      can [:order_questions, :csv_answers_streets, :csv_answers_votes], Poll::Question
      can [:verify, :unverify], User

      can :edit_physical_votes, Budget::Investment do |investment|
        investment.budget.phase == "selecting"
      end

      can :manage, ModalNotification
      can [:index, :import], RegisteredAddress
      can [:index, :update, :destroy], RegisteredAddress::Grouping
      can [:index], RegisteredAddress::Street

      can [:results, :stats], Poll, projekt_phase: { settings: { key: "feature.resource.intermediate_poll_results_for_admins", value: "active" }}
    end
  end
end
