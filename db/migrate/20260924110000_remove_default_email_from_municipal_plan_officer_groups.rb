class RemoveDefaultEmailFromMunicipalPlanOfficerGroups < ActiveRecord::Migration[6.1]
  def change
    remove_column :municipal_plan_officer_groups, :default_email, :string
  end
end
