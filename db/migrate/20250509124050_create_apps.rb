class CreateApps < ActiveRecord::Migration[6.1]
  def change
    create_table :apps do |t|
      t.integer :status
      t.string :codename

      t.timestamps
    end
  end
end
