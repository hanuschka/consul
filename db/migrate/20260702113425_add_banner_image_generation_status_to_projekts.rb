class AddBannerImageGenerationStatusToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :banner_image_generation_status, :string
  end
end
