class AddAdmEmailOnNewTopicToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :adm_email_on_new_topic, :boolean, default: false
  end
end
