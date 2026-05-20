class RenameProjektPhaseProposalCriteriaToUserResourceCriteria < ActiveRecord::Migration[6.1]
  def change
    rename_table :projekt_phase_proposal_criteria, :user_resource_criteria
  end
end
