class AddContentBuToSiteCustomizationPage < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        SiteCustomization::Page.add_translation_fields! content_bu: :text
        SiteCustomization::Page::Translation.update_all("content_bu = content")
      end

      dir.down do
        remove_column :site_customization_page_translations, :content_bu
      end
    end
  end
end
