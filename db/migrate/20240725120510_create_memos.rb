class CreateMemos < ActiveRecord::Migration[6.1]
  def change
    create_table :memos do |t|
      t.references :memoable, polymorphic: true
      t.references :user, foreign_key: true
      t.text :text
      t.datetime :hidden_at

      t.timestamps
    end

    add_index :memos, [:memoable_id, :memoable_type]
    add_index :memos, :hidden_at
  end
end
