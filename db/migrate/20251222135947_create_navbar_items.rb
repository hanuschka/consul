class CreateNavbarItems < ActiveRecord::Migration[6.1]
  def change
    create_table :navbar_items do |t|
      t.integer :kind

      t.string :preset

      t.references :projekt, null: true, foreign_key: true

      t.string :external_title
      t.string :external_url

      t.timestamps
    end
  end
end
