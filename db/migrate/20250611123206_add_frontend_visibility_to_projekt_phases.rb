class AddFrontendVisibilityToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :frontend_visibility, :boolean, default: true, null: false
  end
end
