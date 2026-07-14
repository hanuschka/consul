class AddConditionalToVotes < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :votes, :conditional, :boolean, default: false, null: false
    add_index :votes, :conditional, where: "conditional", algorithm: :concurrently
  end
end
