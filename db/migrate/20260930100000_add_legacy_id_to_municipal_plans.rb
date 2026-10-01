class AddLegacyIdToMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    add_column :municipal_plans, :legacy_id, :string
    add_index :municipal_plans, :legacy_id, unique: true
  end
end
