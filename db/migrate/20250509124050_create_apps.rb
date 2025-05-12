class CreateApps < ActiveRecord::Migration[6.1]
  def change
    create_table :apps do |t|
      t.boolean :enabled, default: false
      t.string :codename

      t.timestamps
    end
  end
end
