class AddAuthImageLinkToUsers < ActiveRecord::Migration[6.1]
  def change
    unless column_exists? :users, :auth_image_link
      add_column :users, :auth_image_link, :string
    end
  end
end
