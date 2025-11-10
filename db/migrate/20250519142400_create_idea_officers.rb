class CreateIdeaOfficers < ActiveRecord::Migration[6.1]
  def change
    create_table :idea_officers do |t|
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
