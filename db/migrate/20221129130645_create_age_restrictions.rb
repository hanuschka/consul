class CreateAgeRestrictions < ActiveRecord::Migration[5.2]
  def change
    create_table :age_restrictions do |t|
      t.integer :order
      t.integer :min_age
      t.integer :max_age

      t.timestamps
    end

    # replaced with db/migrate/20240304164551_rename_age_restriction.rb
    # reversible do |dir|
    #   dir.up do
    #     AgeRestriction.create_translation_table! name: :string
    #   end

    #   dir.down do
    #     AgeRestriction.drop_translation_table!
    #   end
    # end
  end
end
