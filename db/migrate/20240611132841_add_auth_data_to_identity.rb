class AddAuthDataToIdentity < ActiveRecord::Migration[6.1]
  def change
    add_column :identities, :auth_data, :text, default: ""
  end
end
