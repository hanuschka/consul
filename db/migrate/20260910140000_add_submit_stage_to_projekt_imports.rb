class AddSubmitStageToProjektImports < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_imports, :submit_stage, :string
  end
end
