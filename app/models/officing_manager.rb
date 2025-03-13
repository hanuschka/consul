class OfficingManager < ApplicationRecord
  belongs_to :user, touch: true
  delegate :name, :email, to: :user

  has_many :assignments, class_name: "OfficingManagerAssignment", dependent: :destroy
  has_many :projekt_phases, through: :assignments

  def officing_polls
    projekt_phases
      .where("type = 'ProjektPhase::VotingPhase' AND (lock_on IS NULL OR lock_on >= ?)", Time.zone.now.to_date)
      .map(&:poll)
  end

  def officing_proposal_phases
    projekt_phases
      .where("type = 'ProjektPhase::ProposalPhase' AND (lock_on IS NULL OR lock_on >= ?)", Time.zone.now.to_date)
  end

  def selecting_budgets
    projekt_phases
      .where("type = 'ProjektPhase::BudgetPhase' AND (lock_on IS NULL OR lock_on >= ?)", Time.zone.now.to_date)
      .select { |pp| pp.budget.selecting?	|| pp.budget.valuating? }
      .map(&:budget)
  end

  def balloting_budgets
    projekt_phases
      .where("type = 'ProjektPhase::BudgetPhase' AND (lock_on IS NULL OR lock_on >= ?)", Time.zone.now.to_date)
      .select { |pp| pp.budget.balloting?	|| pp.budget.reviewing_ballots? }
      .map(&:budget)
  end
end
