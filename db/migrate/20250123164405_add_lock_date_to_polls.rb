class AddLockDateToPolls < ActiveRecord::Migration[6.1]
  def change
    add_column :polls, :lock_on, :date
  end
end
