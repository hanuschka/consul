class AddTsvToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :tsv, :tsvector
    add_index :projekts, :tsv, using: :gin
  end
end
