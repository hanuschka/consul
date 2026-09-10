class AddCopyDataToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :copy_data, :jsonb
  end
end
