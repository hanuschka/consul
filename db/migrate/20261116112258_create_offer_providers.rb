class CreateOfferProviders < ActiveRecord::Migration[6.1]
  def change
    create_table :offer_providers do |t|
      t.string :name, null: false
      t.text :auto_join_emails, array: true, default: [], null: false

      t.timestamps
    end

    create_table :offer_provider_users do |t|
      t.references :offer_provider, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :offer_provider_users, [:offer_provider_id, :user_id],
      unique: true, name: "index_offer_provider_users_unique"

    add_reference :offers, :provider, foreign_key: { to_table: :offer_providers }
  end
end
