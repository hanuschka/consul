class AddVotesDownToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :cached_votes_down, :integer, default: 0
    add_index :proposals, :cached_votes_down
  end
end
