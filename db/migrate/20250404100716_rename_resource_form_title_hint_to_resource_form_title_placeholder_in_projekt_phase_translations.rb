class RenameResourceFormTitleHintToResourceFormTitlePlaceholderInProjektPhaseTranslations < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekt_phase_translations, :resource_form_title_hint, :resource_form_title_placeholder
  end
end
