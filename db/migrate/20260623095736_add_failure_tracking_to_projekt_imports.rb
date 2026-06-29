class AddFailureTrackingToProjektImports < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_imports, :failure_stage, :string
    add_column :projekt_imports, :error_details, :jsonb, null: false, default: {}
  end
end
