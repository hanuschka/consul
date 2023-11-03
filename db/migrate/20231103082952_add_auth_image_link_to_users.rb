class AddAuthImageLinkToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :auth_image_link, :string
  end
end
