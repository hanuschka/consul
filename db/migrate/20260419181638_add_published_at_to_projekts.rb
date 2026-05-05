class AddPublishedAtToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :published_at, :datetime
    add_index :projekts, :published_at
  end
end
