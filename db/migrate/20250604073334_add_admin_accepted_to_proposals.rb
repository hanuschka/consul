class AddAdminAcceptedToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :admin_accepted, :boolean, default: true, null: false
  end
end
