require_dependency Rails.root.join("app", "models", "budget", "investment").to_s

class Budget
  class Investment < ApplicationRecord
    include OnBehalfOfSubmittable
    include Labelable
    include Sentimentable
    include Memoable
    include ConditionallyVotable

    default_scope { where(draft: false) }

    DEFAULT_ORDERS = %w[
      random total_votes ballot_line_weight newest comments_count
    ].freeze

    delegate :projekt, :projekt_phase, :find_or_create_stats_version, :show_percentage_values_only?,
to: :budget

    delegate :approximated_address, to: :map_location, allow_nil: true

    has_many :budget_ballot_lines, class_name: "Budget::Ballot::Line"
    belongs_to :masterportal_pin, optional: true

    scope :seen, -> { where.not(ignored_flag_at: nil) }
    scope :unseen, -> { where(ignored_flag_at: nil) }
    scope :preselected, -> { where(preselected: true) }
    scope :not_preselected, -> { where(preselected: false) }
    scope :masterportal_linked, -> { where.not(masterportal_pin_id: nil) }
    scope :user_created, -> { where(masterportal_pin_id: nil) }

    enum implementation_performer: { city: 0, user: 1 }

    scope :sort_by_newest, -> { reorder(created_at: :desc) }

    # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
    validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom
    validate :description_sanitized #custom

    def self.sort_by_total_votes
      left_joins(:votes_for)
        .group("budget_investments.id")
        .order(Arel.sql("COALESCE(SUM(CASE WHEN votes.conditional = false THEN votes.vote_weight ELSE 0 END), 0) + budget_investments.physical_votes DESC"))
    end

    def self.sort_by_ballot_line_weight
      left_joins(budget_ballot_lines: :ballot)
        .group("budget_investments.id")
        .order(Arel.sql("COALESCE(SUM(CASE WHEN budget_ballots.conditional = false THEN budget_ballot_lines.line_weight ELSE 0 END), 0) DESC"))
    end

    def register_selection(user, vote_weight = 1)
      vote_by(voter: user, vote: "yes", vote_weight:) if selectable_by?(user)
    end

    def sentiment_required?
      super && masterportal_pin_id.blank?
    end

    def total_supporters
      votes_for.where(conditional: false).joins("INNER JOIN users ON voter_id = users.id").count
    end

    def total_votes
      votes_for.where(conditional: false).sum(:vote_weight) + physical_votes
    end

    def total_ballot_votes
      budget_ballot_lines.joins(:ballot).where(budget_ballots: { conditional: false }).sum(:line_weight)
    end

    def total_ballot_votes_percentage
      return 0 if total_ballot_votes.zero?

      (total_ballot_votes.to_f / heading.total_ballot_votes.to_f) * 100.0
    end

    def permission_problem(user, location: nil)
      budget.projekt_phase.permission_problem(user, location:)
    end

    def conditional_vote_confirmable_for?(user)
      budget.selecting? && reason_for_not_being_selectable_by(user).blank?
    end

    def comments_allowed?(user)
      return false if unfeasible? && valuation_finished?
      return false unless budget.current_phase.kind.in? %w[informing accepting]

      permission_problem(user).nil?
    end

    def permission_problem_keys_allowing_ballot_line_deletion
      [:not_enough_available_votes, :not_enough_money]
    end

    def final_winner?
      selected? && !incompatible? && winner?
    end

    def should_show_feasibility_explanation?
      feasible? &&
        selected? &&
        valuator_explanation.present?
    end
  end
end
