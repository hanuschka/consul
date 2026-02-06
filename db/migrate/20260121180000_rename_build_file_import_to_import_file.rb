class RenameBuildFileImportToImportFile < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekts, :build_file_import_status, :import_file_status
    rename_column :projekts, :build_file_import_data, :import_file_data
  end
end
