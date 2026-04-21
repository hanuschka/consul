class CreateLandingPageManagers < ActiveRecord::Migration[6.1]
  def change
    create_table :landing_page_managers do |t|
      t.references :user, foreign_key: true
      t.boolean :manage_all_landing_pages, default: false, null: false

      t.timestamps
    end
  end
end
