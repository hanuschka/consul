class AddImportStatusToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :import_file_status, :string
    add_column :projekts, :import_file_data, :jsonb
  end
end
