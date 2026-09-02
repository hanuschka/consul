class AddKeyValueProjektIdIndexToProjektSettings < ActiveRecord::Migration[6.1]
  def change
    add_index :projekt_settings, [:key, :value, :projekt_id],
      name: "index_projekt_settings_on_key_and_value_and_projekt_id"
  end
end
