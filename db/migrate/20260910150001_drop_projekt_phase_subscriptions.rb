class DropProjektPhaseSubscriptions < ActiveRecord::Migration[6.1]
  def change
    drop_table :projekt_phase_subscriptions do |t|
      t.bigint "projekt_phase_id"
      t.bigint "user_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["projekt_phase_id"], name: "index_projekt_phase_subscriptions_on_projekt_phase_id"
      t.index ["user_id"], name: "index_projekt_phase_subscriptions_on_user_id"
    end
  end
end
