class CreateIdeas < ActiveRecord::Migration[6.1]
  def change
    create_table :ideas do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }, index: true
      t.string :video_url
      t.datetime :hidden_at
      t.boolean :admin_accepted
      t.datetime :archived_at
      t.tsvector :tsv
      t.string :on_behalf_of
      t.integer :comments_count, default: 0

      t.timestamps
    end

    add_index :ideas, :tsv, using: :gin

    reversible do |dir|
      dir.up do
        Idea.create_translation_table! title: :string, description: :text
      end

      dir.down do
        Idea.drop_translation_table!
      end
    end
  end
end
