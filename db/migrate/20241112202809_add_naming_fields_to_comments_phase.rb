class AddNamingFieldsToCommentsPhase < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        ProjektPhase.add_translation_fields! comment_form_title: :string, comment_form_button: :string
      end

      dir.down do
        remove_column :projekt_phases, :comment_form_title
        remove_column :projekt_phases, :comment_form_button
      end
    end
  end
end
