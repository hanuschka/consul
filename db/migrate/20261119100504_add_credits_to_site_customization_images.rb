class AddCreditsToSiteCustomizationImages < ActiveRecord::Migration[7.2]
  def change
    add_column :site_customization_images, :credits, :string
  end
end
