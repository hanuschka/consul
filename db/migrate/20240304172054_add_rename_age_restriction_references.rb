class AddRenameAgeRestrictionReferences < ActiveRecord::Migration[6.1]
  def change
    rename_column :age_range_translations, :age_restriction_id, :age_range_id
    rename_column :projekt_phases, :age_restriction_id, :age_range_id
  end
end
