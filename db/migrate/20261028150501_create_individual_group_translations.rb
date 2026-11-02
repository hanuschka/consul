class CreateIndividualGroupTranslations < ActiveRecord::Migration[6.1]
  def up
    Globalize.with_locale(I18n.default_locale) do
      IndividualGroup.create_translation_table!({ name: :string }, { migrate_data: true })
      IndividualGroupValue.create_translation_table!({ name: :string }, { migrate_data: true })
    end
  end

  def down
    IndividualGroup.drop_translation_table!(migrate_data: true)
    IndividualGroupValue.drop_translation_table!(migrate_data: true)
  end
end
