class RemoveShareTokenFromProjektEvaluations < ActiveRecord::Migration[6.1]
  def change
    remove_index :projekt_evaluations, :share_token
    remove_column :projekt_evaluations, :share_token, :string
  end
end
