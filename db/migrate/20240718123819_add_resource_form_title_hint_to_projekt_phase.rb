class AddResourceFormTitleHintToProjektPhase < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        ProjektPhase.add_translation_fields! resource_form_title_hint: :string
      end

      dir.down do
        remove_column :projekt_phase_translations, :resource_form_title_hint
      end
    end
  end
end
