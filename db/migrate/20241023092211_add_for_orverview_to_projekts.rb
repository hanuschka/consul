class AddForOrverviewToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :for_global_overview, :boolean, default: false
    add_index :projekts, :for_global_overview
  end
end
