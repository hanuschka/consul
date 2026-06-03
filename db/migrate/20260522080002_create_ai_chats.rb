class CreateAiChats < ActiveRecord::Migration[6.1]
  def change
    create_table :ai_chats do |t|
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.string :ai_provider
      t.string :ai_model
      t.boolean :running, null: false, default: false
      t.timestamps
    end

    add_index :ai_chats, [:resource_type, :resource_id]
  end
end
