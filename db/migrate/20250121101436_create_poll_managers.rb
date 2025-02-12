class CreatePollManagers < ActiveRecord::Migration[6.1]
  def change
    create_table :poll_managers do |t|
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
