class RemoveInternalNotesFromMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    remove_column :municipal_plans, :internal_notes, :text
  end
end
