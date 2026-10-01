class CreateMunicipalPlanTopics < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plan_topics do |t|
      t.integer :given_order

      t.timestamps
    end

    create_table :municipal_plan_topic_translations do |t|
      t.bigint :municipal_plan_topic_id, null: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :municipal_plan_topic_translations, :municipal_plan_topic_id,
      name: "index_mp_topic_translations_on_topic_id"
    add_index :municipal_plan_topic_translations, :locale,
      name: "index_mp_topic_translations_on_locale"

    create_table :municipal_plan_topic_assignments do |t|
      t.bigint :municipal_plan_id, null: false
      t.bigint :municipal_plan_topic_id, null: false

      t.timestamps
    end

    add_index :municipal_plan_topic_assignments, :municipal_plan_id,
      name: "index_mp_topic_assignments_on_plan_id"
    add_index :municipal_plan_topic_assignments, :municipal_plan_topic_id,
      name: "index_mp_topic_assignments_on_topic_id"
    add_index :municipal_plan_topic_assignments,
      [:municipal_plan_id, :municipal_plan_topic_id],
      unique: true, name: "index_mp_topic_assignments_unique"
  end
end
