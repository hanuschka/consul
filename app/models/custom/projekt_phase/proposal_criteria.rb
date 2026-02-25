class ProjektPhase::ProposalCriteria < ApplicationRecord
  self.table_name = "projekt_phase_proposal_criteria"

  belongs_to :projekt_phase
  validates :text, presence: true
  default_scope { order(:position) }
end
