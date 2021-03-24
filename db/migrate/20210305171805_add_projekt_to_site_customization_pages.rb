class AddProjektToSiteCustomizationPages < ActiveRecord::Migration[5.1]
  def change
    add_reference :site_customization_pages, :projekt, foreign_key: true
  end
end
