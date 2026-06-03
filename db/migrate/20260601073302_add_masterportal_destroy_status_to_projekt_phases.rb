class AddMasterportalDestroyStatusToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :masterportal_destroy_status, :string
    add_column :projekt_phases, :masterportal_destroy_error, :text
  end
end
