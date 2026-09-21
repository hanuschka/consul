class CreateMunicipalPlans < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plans do |t|
      t.string :status, null: false, default: "draft"
      t.string :version, null: false, default: "1.0"
      t.date :content_updated_at
      t.integer :given_order
      t.boolean :formal_participation, null: false, default: false
      t.boolean :informal_participation, null: false, default: false
      t.string :contact_name
      t.string :contact_phone
      t.string :contact_email
      t.string :system_mailbox_email
      t.text :internal_notes
      t.string :responsible_type
      t.bigint :responsible_id

      t.timestamps
    end

    add_index :municipal_plans, :status
    add_index :municipal_plans, :given_order
    add_index :municipal_plans, [:responsible_type, :responsible_id],
      name: "index_municipal_plans_on_responsible"

    create_table :municipal_plan_translations do |t|
      t.bigint :municipal_plan_id, null: false
      t.string :locale, null: false
      t.string :title
      t.text :short_description
      t.text :further_information
      t.text :last_resolution
      t.text :processing_status
      t.text :next_steps
      t.string :costs
      t.text :formal_participation_reason
      t.text :informal_participation_reason
      t.string :contact_role

      t.timestamps
    end

    add_index :municipal_plan_translations, :municipal_plan_id,
      name: "index_municipal_plan_translations_on_plan_id"
    add_index :municipal_plan_translations, :locale,
      name: "index_municipal_plan_translations_on_locale"
  end
end
