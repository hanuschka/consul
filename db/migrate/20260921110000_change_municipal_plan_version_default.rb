class ChangeMunicipalPlanVersionDefault < ActiveRecord::Migration[6.1]
  def up
    change_column_default :municipal_plans, :version, from: "1.0", to: "0.1"
  end

  def down
    change_column_default :municipal_plans, :version, from: "0.1", to: "1.0"
  end
end
