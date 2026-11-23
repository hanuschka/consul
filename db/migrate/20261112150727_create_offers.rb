class CreateOffers < ActiveRecord::Migration[6.1]
  def change
    create_table :offers do |t|
      t.string :address
      t.string :contact_name
      t.string :contact_phone
      t.string :contact_email
      t.string :contact_website
      t.references :author, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    create_table :offer_translations do |t|
      t.bigint :offer_id, null: false
      t.string :locale, null: false
      t.string :title
      t.text :short_description
      t.text :times
      t.text :costs
      t.text :registration

      t.timestamps
    end

    add_index :offer_translations, :offer_id
    add_index :offer_translations, :locale

    create_table :offer_categories do |t|
      t.string :kind, null: false
      t.integer :given_order

      t.timestamps
    end

    add_index :offer_categories, [:kind, :given_order]

    create_table :offer_category_translations do |t|
      t.bigint :offer_category_id, null: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :offer_category_translations, :offer_category_id
    add_index :offer_category_translations, :locale

    create_table :offer_category_assignments do |t|
      t.references :offer, null: false, foreign_key: true
      t.references :offer_category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :offer_category_assignments, [:offer_id, :offer_category_id],
      unique: true, name: "index_offer_category_assignments_unique"
  end
end
