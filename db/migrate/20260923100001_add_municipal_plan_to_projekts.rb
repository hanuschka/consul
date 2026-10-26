class AddMunicipalPlanToProjekts < ActiveRecord::Migration[6.1]
  def change
    return if column_exists?(:projekts, :municipal_plan_id)

    add_reference :projekts, :municipal_plan, foreign_key: { on_delete: :nullify }
  end
end
