class AddTitleColorAndSubtitleColorToNewsletters < ActiveRecord::Migration[6.1]
  def change
    add_column :newsletters, :title_color, :string, null: false, default: "#000000"
    add_column :newsletters, :subtitle_color, :string, null: false, default: "#000000"
  end
end
