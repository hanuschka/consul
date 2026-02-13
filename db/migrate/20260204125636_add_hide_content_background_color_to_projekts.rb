class AddHideContentBackgroundColorToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :hide_content_background_color, :boolean, default: false
  end
end
