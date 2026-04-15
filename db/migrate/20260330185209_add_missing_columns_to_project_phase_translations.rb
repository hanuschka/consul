class AddMissingColumnsToProjectPhaseTranslations < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phase_translations, :resource_form_intro, :text unless column_exists?(:projekt_phase_translations, :resource_form_intro)
    add_column :projekt_phase_translations, :resource_form_title_placeholder, :text unless column_exists?(:projekt_phase_translations, :resource_form_title_placeholder)
    add_column :projekt_phase_translations, :resource_form_description_placeholder, :text unless column_exists?(:projekt_phase_translations, :resource_form_description_placeholder)
  end
end
