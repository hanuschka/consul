class AddRenameAgeRestrictionReferences < ActiveRecord::Migration[6.1]
  def change
    if ActiveRecord::Base.connection.column_exists?(:age_range_translations, :age_restriction_id)
      rename_column :age_range_translations, :age_restriction_id, :age_range_id
    end

    rename_column :projekt_phases, :age_restriction_id, :age_range_id
  end
end
