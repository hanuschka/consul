class AddCityWideToMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    add_column :municipal_plans, :city_wide, :boolean, default: false, null: false
  end
end
