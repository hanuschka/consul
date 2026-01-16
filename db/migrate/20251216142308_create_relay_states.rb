class CreateRelayStates < ActiveRecord::Migration[6.1]
  def change
    create_table :relay_states do |t|
      t.string :token
      t.jsonb :data, default: {}

      t.timestamps
    end
    add_index :relay_states, :token
  end
end
