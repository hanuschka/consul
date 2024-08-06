class AddLastStorkLevelToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :last_stork_level, :string, default: nil
  end
end
