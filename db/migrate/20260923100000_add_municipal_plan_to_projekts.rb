class AddMunicipalPlanToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_reference :projekts, :municipal_plan, foreign_key: { on_delete: :nullify }
  end
end
