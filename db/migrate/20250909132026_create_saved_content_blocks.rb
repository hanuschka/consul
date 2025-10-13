class CreateSavedContentBlocks < ActiveRecord::Migration[6.1]
  def change
    create_table :saved_content_blocks do |t|
      t.text :content

      t.timestamps
    end
  end
end
