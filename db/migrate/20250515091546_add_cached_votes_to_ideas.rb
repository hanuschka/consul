class AddCachedVotesToIdeas < ActiveRecord::Migration[6.1]
  def change
    change_table :ideas do |t|
      t.integer :cached_votes_up, default: 0
    end
  end
end
