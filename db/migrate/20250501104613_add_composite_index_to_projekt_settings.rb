class AddCompositeIndexToProjektSettings < ActiveRecord::Migration[6.1]
  def change
    add_index :projekt_settings, [:projekt_id, :key, :value],
      name: "index_projekt_settings_on_projekt_id_key_value"
  end
end
