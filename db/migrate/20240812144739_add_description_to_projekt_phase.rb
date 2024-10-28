class AddDescriptionToProjektPhase < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        ProjektPhase.add_translation_fields! description: :text
      end

      dir.down do
        remove_column :projekt_phase_translations, :description
      end
    end
  end
end
