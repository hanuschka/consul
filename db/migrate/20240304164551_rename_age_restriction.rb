class RenameAgeRestriction < ActiveRecord::Migration[6.1]
  def change
    rename_table :age_restrictions, :age_ranges
    rename_table :age_restriction_translations, :age_range_translations
  end
end
