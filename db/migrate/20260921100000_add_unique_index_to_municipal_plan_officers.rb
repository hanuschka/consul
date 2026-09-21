class AddUniqueIndexToMunicipalPlanOfficers < ActiveRecord::Migration[6.1]
  def change
    remove_index :municipal_plan_officers, :user_id
    add_index :municipal_plan_officers, :user_id, unique: true
  end
end
