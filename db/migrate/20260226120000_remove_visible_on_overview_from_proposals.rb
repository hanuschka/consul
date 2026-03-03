class RemoveVisibleOnOverviewFromProposals < ActiveRecord::Migration[6.1]
  def change
    remove_column :proposals, :visible_on_overview, :boolean, default: true, null: false
  end
end
