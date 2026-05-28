class CreateRecipientGroupFilters < ActiveRecord::Migration[6.1]
  def change
    create_table :recipient_group_filters do |t|
      t.references :recipient_group, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :kind, null: false
      t.string :operator, null: false, default: "include"
      t.jsonb :params, null: false, default: {}
      t.timestamps
    end

    add_index :recipient_group_filters, [:recipient_group_id, :position], name: "index_rgf_on_recipient_group_id_and_position"
    add_index :recipient_group_filters, :kind
  end
end
