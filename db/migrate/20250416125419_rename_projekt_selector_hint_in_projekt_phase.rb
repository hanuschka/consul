class RenameProjektSelectorHintInProjektPhase < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekt_phase_translations, :projekt_selector_hint, :resource_form_intro
  end
end
