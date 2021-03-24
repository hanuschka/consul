class CreateProjektProposalJoinTable < ActiveRecord::Migration[5.1]
  def change
    create_join_table :proposals, :projekts do |t|
      # t.index [:proposal_id, :projekt_id]
      t.index [:projekt_id, :proposal_id], unique: true
    end
  end
end
