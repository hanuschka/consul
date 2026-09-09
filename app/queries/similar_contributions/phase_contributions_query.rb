# The published contributions of a phase -- the ones a check has already run
# for, and so the ones a re-check has to look at again. Phase types that take
# no contributions answer with an empty relation rather than being asked about
# elsewhere.
class SimilarContributions::PhaseContributionsQuery < ApplicationQuery
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    return proposals if projekt_phase.is_a?(ProjektPhase::ProposalPhase)
    return investments if projekt_phase.is_a?(ProjektPhase::BudgetPhase)

    Proposal.none
  end

  private

    attr_reader :projekt_phase

    def proposals
      projekt_phase.proposals.base_selection
    end

    def investments
      budget = projekt_phase.budget

      return Budget::Investment.none if budget.blank?

      budget.investments.where(draft: false)
    end
end
