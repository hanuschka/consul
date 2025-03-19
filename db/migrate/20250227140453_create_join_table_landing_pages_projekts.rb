class CreateJoinTableLandingPagesProjekts < ActiveRecord::Migration[6.1]
  def change
    drop_table :landing_page_resources

    create_table :landing_pages_projekts do |t|
      t.references :site_customization_page, null: false
      t.references :projekt, null: false

      t.index [:site_customization_page_id, :projekt_id], unique: true, name: 'index_scp_projekts'
      t.index [:projekt_id, :site_customization_page_id], name: 'index_projekts_scp'
    end
  end
end
