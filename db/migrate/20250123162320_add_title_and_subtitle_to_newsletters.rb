class AddTitleAndSubtitleToNewsletters < ActiveRecord::Migration[6.1]
  def change
    add_column :newsletters, :title, :string
    add_column :newsletters, :subtitle, :text
  end
end
