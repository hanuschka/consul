class AddHeaderTitleToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        SiteCustomization::Page.add_translation_fields! header_title: :string

        execute <<-SQL.squish
          UPDATE site_customization_page_translations
          SET header_title = title
        SQL
      end

      dir.down do
        remove_column :site_customization_page_translations, :header_title
      end
    end
  end
end
