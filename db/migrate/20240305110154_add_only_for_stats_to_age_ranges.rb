class AddOnlyForStatsToAgeRanges < ActiveRecord::Migration[6.1]
  def change
    add_column :age_ranges, :only_for_stats, :boolean, default: false
  end
end
