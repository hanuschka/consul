class DropAppsTable < ActiveRecord::Migration[6.1]
  def change
    drop_table :apps, if_exists: true
  end
end
