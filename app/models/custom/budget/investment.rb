require_dependency Rails.root.join("app", "models", "budget", "investment").to_s

class Budget
  class Investment < ApplicationRecord
    include OnBehalfOfSubmittable
    include Labelable
    include Sentimentable

    delegate :projekt, :projekt_phase, :find_or_create_stats_version, :show_percentage_values_only?, to: :budget

    has_many :budget_ballot_lines, class_name: "Budget::Ballot::Line"

    scope :seen, -> { where.not(ignored_flag_at: nil) }
    scope :unseen, -> { where(ignored_flag_at: nil) }

    enum implementation_performer: { city: 0, user: 1 }

    scope :sort_by_newest, -> { reorder(created_at: :desc) }

    # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
    validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom

    def self.sort_by_ballot_line_weight
      left_joins(:budget_ballot_lines)
        .group("budget_investments.id")
        .select("budget_investments.*, COALESCE(SUM(budget_ballot_lines.line_weight), 0) AS total_ballot_line_weight")
        .order("total_ballot_line_weight DESC")
    end

    def register_selection(user, vote_weight = 1)
      vote_by(voter: user, vote: "yes", vote_weight: vote_weight) if selectable_by?(user)
    end

    def total_supporters
      votes_for.joins("INNER JOIN users ON voter_id = users.id").count
    end

    def total_votes
      if budget.distributed_voting?
        votes_for.sum(:vote_weight) + physical_votes
      else
        cached_votes_up + physical_votes
      end
    end

    def total_ballot_votes
      budget_ballot_lines.joins(:ballot).where(budget_ballots: { conditional: false }).sum(:line_weight)
    end

    def total_ballot_votes_percentage
      return 0 if total_ballot_votes.zero?

      (total_ballot_votes.to_f / heading.total_ballot_votes.to_f) * 100.0
    end

    def permission_problem(user)
      budget.projekt_phase.permission_problem(user)
    end

    def comments_allowed?(user)
      permission_problem(user).nil?
    end

    def permission_problem_keys_allowing_ballot_line_deletion
      [:not_enough_available_votes, :not_enough_money]
    end

    def final_winner?
      selected? && !incompatible? && winner?
    end

    def should_show_feasibility_explanation?
      return if should_show_price?

      feasible? &&
        selected? && budget.published_prices? &&
        price_explanation.present?
    end
  end
end
