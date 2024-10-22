require_dependency Rails.root.join("app", "models", "budget").to_s

class Budget < ApplicationRecord
  belongs_to :projekt_phase, optional: true
  delegate :projekt, to: :projekt_phase, allow_nil: true

  has_one :group, dependent: :destroy
  has_one :heading, through: :group

  accepts_nested_attributes_for :heading

  def investments_filters
    [
      ("all" if selecting? || valuating? || publishing_prices? || balloting? || reviewing_ballots?),
      ("winners" if finished?),
      ("selected" if publishing_prices_or_later? && !finished? && investments.selected.any?),
      # ("unselected" if publishing_prices_or_later?),
      ("unselected" if finished? && investments.unselected.any?),
      ("feasible" if (selecting? || valuating?) && investments.feasible.any?),
      ("unfeasible" if (selecting? || valuating_or_later?) && investments.unfeasible.any?),
      ("undecided" if selecting? || valuating?)
    ].compact
  end

  def knapsack_voting?
    voting_style == "knapsack"
  end

  def distributed_voting?
    voting_style == "distributed"
  end

  def find_or_create_stats_version
    balloting_phase_ends_at = phases.find_by(kind: "balloting").ends_at

    if balloting_phase_ends_at.present? &&
        ((Time.zone.today - balloting_phase_ends_at.to_date).to_i <= 3) &&
        stats_version &&
        stats_version.created_at.to_date != Time.zone.today.to_date
      stats_version.destroy
    end

    super
  end

  def stats_age_groups
    return [] unless projekt_phase.present?

    projekt_phase.age_ranges_for_stats.map { |ar| [ar.min_age, ar.max_age] }
  end
end
