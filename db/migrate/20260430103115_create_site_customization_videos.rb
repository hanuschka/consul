class CreateSiteCustomizationVideos < ActiveRecord::Migration[6.1]
  def change
    create_table :site_customization_videos do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :site_customization_videos, :name, unique: true
  end
end
