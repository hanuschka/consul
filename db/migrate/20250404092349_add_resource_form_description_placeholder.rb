class AddResourceFormDescriptionPlaceholder < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        ProjektPhase.add_translation_fields! resource_form_description_placeholder: :text

        execute <<-SQL
          UPDATE projekt_phase_translations AS ppt
          SET resource_form_description_placeholder = resource_form_title_hint,
              resource_form_title_hint = NULL
          FROM projekt_phases AS pp
          WHERE ppt.projekt_phase_id = pp.id
            AND pp.type IN ('ProjektPhase::DebatePhase', 'ProjektPhase::ProposalPhase')
            AND ppt.resource_form_title_hint IS NOT NULL
        SQL
      end

      dir.down do
        remove_column :projekt_phase_translations, :resource_form_description_placeholder
      end
    end
  end
end
