class CreateSiteCustomizationContentCards < ActiveRecord::Migration[6.1]
  def change
    create_table :site_customization_content_cards do |t|
      t.integer :given_order
      t.boolean :active, default: false
      t.jsonb :settings, default: {}
      t.string :kind

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        SiteCustomization::ContentCard.create_translation_table! title: :string
      end

      dir.down do
        SiteCustomization::ContentCard.drop_translation_table!
      end
    end
  end
end
