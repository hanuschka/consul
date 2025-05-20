class CreateIdeaCategories < ActiveRecord::Migration[6.1]
  def change
    create_table :idea_categories do |t|
      t.string :color
      t.string :icon
      t.integer :given_order

      t.timestamps
    end

    add_reference :ideas, :idea_category, foreign_key: true

    reversible do |dir|
      dir.up do
        Idea::Category.create_translation_table! name: :string
      end

      dir.down do
        Idea::Category.drop_translation_table!
      end
    end
  end
end
