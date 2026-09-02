class AddContentUpdatedAtToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :content_updated_at, :datetime
  end
end
