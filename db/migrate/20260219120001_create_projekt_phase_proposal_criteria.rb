class CreateProjektPhaseProposalCriteria < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_phase_proposal_criteria do |t|
      t.bigint :projekt_phase_id, null: false
      t.text :text, null: false
      t.integer :position, default: 0, null: false

      t.timestamps precision: 6
    end

    add_index :projekt_phase_proposal_criteria, [:projekt_phase_id, :position],
      name: "idx_pf_proposal_criteria_phase_position"
    add_index :projekt_phase_proposal_criteria, :projekt_phase_id

    add_foreign_key :projekt_phase_proposal_criteria, :projekt_phases
  end
end
