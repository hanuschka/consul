class AddArchiveOnToMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    add_column :municipal_plans, :archive_on, :date
  end
end
