class RenameAgeRestriction < ActiveRecord::Migration[6.1]
  def change
    rename_table :age_restrictions, :age_ranges

    # look into db/migrate/20221129130645_create_age_restrictions.rb
    if ActiveRecord::Base.connection.table_exists? :age_restriction_translations
      rename_table :age_restriction_translations, :age_range_translations
    else
      reversible do |dir|
        dir.up do
          AgeRange.create_translation_table! name: :string
        end

        dir.down do
          AgeRange.drop_translation_table!
        end
      end
    end
  end
end
