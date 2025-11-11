class AddWelcomeTextInShowToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        ProjektPhase.add_translation_fields! welcome_text_in_show: :text
      end

      dir.down do
        remove_column :projekt_phase_translations, :welcome_text_in_show
      end
    end
  end
end
