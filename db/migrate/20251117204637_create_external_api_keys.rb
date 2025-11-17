class CreateExternalApiKeys < ActiveRecord::Migration[6.1]
  def change
    create_table :external_api_keys do |t|
      t.string :name
      t.text :value

      t.timestamps
    end
  end
end
