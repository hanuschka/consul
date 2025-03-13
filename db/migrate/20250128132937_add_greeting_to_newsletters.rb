class AddGreetingToNewsletters < ActiveRecord::Migration[6.1]
  def change
    add_column :newsletters, :greeting, :string
  end
end
