class CreateLandingPageResources < ActiveRecord::Migration[6.1]
  def change
    create_table :landing_page_resources do |t|
      t.references :landing_page, null: false
      t.references :resource, polymorphic: true, null: false

      t.timestamps
    end
  end
end
