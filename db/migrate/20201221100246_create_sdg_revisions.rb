class CreateSDGRevisions < ActiveRecord::Migration[5.2]
  def change
    create_table :sdg_revisions do |t|
      t.references :relatable, polymorphic: true, index: { unique: true }
      t.timestamps
    end
  end
end
