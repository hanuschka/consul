class AddLiveToPolls < ActiveRecord::Migration[6.1]
  def change
    add_column :polls, :live, :boolean, default: true, null: false
  end
end
