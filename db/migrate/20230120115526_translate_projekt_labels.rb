class TranslateProjektLabels < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      dir.up do
        Projekt::Label.create_translation_table! name: :string
      end

      dir.down do
        Projekt::Label.drop_translation_table!
      end
    end
  end
end
