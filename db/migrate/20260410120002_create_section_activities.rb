class CreateSectionActivities < ActiveRecord::Migration[6.1]
  def change
    create_table :section_activities do |t|
      t.references :user, null: true, foreign_key: true
      t.string :section, null: false
      t.string :trackable_type
      t.bigint :trackable_id
      t.string :action, null: false
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :section_activities, [:section, :created_at]
    add_index :section_activities, [:trackable_type, :trackable_id]
  end
end
