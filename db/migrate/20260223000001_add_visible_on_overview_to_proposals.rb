class AddVisibleOnOverviewToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :visible_on_overview, :boolean, default: true, null: false
  end
end
