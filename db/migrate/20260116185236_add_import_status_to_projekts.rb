class AddImportStatusToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :build_file_import_status, :string
    add_column :projekts, :build_file_import_data, :jsonb
  end
end
