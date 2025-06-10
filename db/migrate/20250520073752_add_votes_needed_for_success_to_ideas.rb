class AddVotesNeededForSuccessToIdeas < ActiveRecord::Migration[6.1]
  def change
    add_column :ideas, :votes_needed_for_success, :integer, default: 0, null: false
  end
end
