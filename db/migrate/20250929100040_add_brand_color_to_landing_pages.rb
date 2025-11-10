class AddBrandColorToLandingPages < ActiveRecord::Migration[6.1]
  def change
    add_column :site_customization_pages, :brand_color, :string
  end
end
