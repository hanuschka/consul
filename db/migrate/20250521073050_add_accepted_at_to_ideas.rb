class AddAcceptedAtToIdeas < ActiveRecord::Migration[6.1]
  def change
    add_column :ideas, :admin_accepted_at, :datetime
    remove_column :ideas, :admin_accepted, :boolean, default: false
    remove_column :ideas, :archived_at, :datetime
  end
end
