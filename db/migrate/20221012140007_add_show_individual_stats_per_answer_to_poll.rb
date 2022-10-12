class AddShowIndividualStatsPerAnswerToPoll < ActiveRecord::Migration[5.2]
  def change
    add_column :polls, :show_individual_stats_per_answer, :boolean, default: false
  end
end
