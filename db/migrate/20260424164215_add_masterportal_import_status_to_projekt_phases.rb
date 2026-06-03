class AddMasterportalImportStatusToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :masterportal_import_status, :string
    add_column :projekt_phases, :masterportal_last_imported_at, :datetime
    add_column :projekt_phases, :masterportal_last_imported_count, :integer
    add_column :projekt_phases, :masterportal_import_error, :text
    add_column :projekt_phases, :masterportal_last_endpoint_url, :string
    add_column :projekt_phases, :masterportal_last_collection_ids, :string
  end
end
