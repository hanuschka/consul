require_dependency Rails.root.join("app", "models", "budget", "investment").to_s

class Budget
  class Investment < ApplicationRecord
    include OnBehalfOfSubmittable
    include Labelable
    include Sentimentable
    include Memoable

    delegate :projekt, :projekt_phase, :find_or_create_stats_version, :show_percentage_values_only?, to: :budget

    has_many :budget_ballot_lines, class_name: "Budget::Ballot::Line"

    scope :seen, -> { where.not(ignored_flag_at: nil) }
    scope :unseen, -> { where(ignored_flag_at: nil) }

    enum implementation_performer: { city: 0, user: 1 }

    scope :sort_by_newest, -> { reorder(created_at: :desc) }

    # validates :terms_of_service, acceptance: { allow_nil: false }, on: :create
    validates :resource_terms, acceptance: { allow_nil: false }, on: :create #custom
    validate :description_sanitized #custom

    def self.sort_by_ballot_line_weight
      left_joins(budget_ballot_lines: :ballot)
        .group("budget_investments.id")
        .order(Arel.sql("COALESCE(SUM(CASE WHEN budget_ballots.conditional = false THEN budget_ballot_lines.line_weight ELSE 0 END), 0) DESC"))
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
      feasible? &&
        selected? &&
        valuator_explanation.present?
    end

    private

      def description_sanitized
        sanitized_description = ActionController::Base.helpers.strip_tags(description).gsub("\n", '').gsub("\r", '').gsub(" ", '').gsub(/^$\n/, '').gsub(/[\u202F\u00A0\u2000\u2001\u2003]/, "")

        errors.add(:description, :too_long, message: 'too long text') if
          sanitized_description.length > Setting[ "extended_option.proposals.description_max_length"].to_i
      end
  end
end
