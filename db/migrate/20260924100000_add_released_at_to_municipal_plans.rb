class AddReleasedAtToMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    add_column :municipal_plans, :released_at, :datetime
  end
end
