class AddSupportButtonTextToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        ProjektPhase.add_translation_fields! support_button_text: :string
      end

      dir.down do
        remove_column :projekt_phase_translations, :support_button_text
      end
    end
  end
end
