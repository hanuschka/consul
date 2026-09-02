class AddLandingAiContextToSiteCustomizationPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :landing_ai_context, :text
  end
end
