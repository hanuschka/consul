class AddActiveIndexesToProjektSubscriptions < ActiveRecord::Migration[6.1]
  def change
    add_index :projekt_subscriptions, [:projekt_id, :active]
    add_index :projekt_subscriptions, [:user_id, :active]
  end
end
