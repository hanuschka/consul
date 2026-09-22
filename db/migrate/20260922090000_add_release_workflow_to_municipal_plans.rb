class AddReleaseWorkflowToMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    add_column :municipal_plans, :submitted_at, :datetime
    add_reference :municipal_plans, :released_plan, foreign_key: { to_table: :municipal_plans },
                                                    index: true
  end
end
