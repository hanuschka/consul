class AddTimeframeToIdea < ActiveRecord::Migration[6.1]
  def change
    add_column :ideas, :timeframe, :integer, default: 50, null: false
    change_column_default :ideas, :votes_needed_for_success, from: 0, to: 100
  end
end
