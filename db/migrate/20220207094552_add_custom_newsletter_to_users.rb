class AddCustomNewsletterToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :custom_newsletter, :boolean, default: false
  end
end
