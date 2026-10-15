class AddTsvectorToMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    add_column :municipal_plans, :tsv, :tsvector
    add_index :municipal_plans, :tsv, using: "gin"
  end
end
