class CreateProjektImports < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_imports do |t|
      t.string :status, null: false, default: "pending"
      t.text :extracted_text
      t.jsonb :ai_result
      t.text :additional_user_instructions
      t.boolean :generate_image, null: false, default: false
      t.references :user, null: false, foreign_key: true
      t.references :projekt, null: true, foreign_key: true
      t.text :error_message
      t.jsonb :warnings, null: false, default: []
      t.string :image_status, null: false, default: "pending"
      t.text :image_error
      t.timestamps
    end

    add_index :projekt_imports, :status
    add_index :projekt_imports, :created_at
  end
end
