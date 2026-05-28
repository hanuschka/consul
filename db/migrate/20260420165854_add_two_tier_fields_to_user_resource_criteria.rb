class AddTwoTierFieldsToUserResourceCriteria < ActiveRecord::Migration[6.1]
  def up
    add_column :user_resource_criteria, :kind, :string, null: false, default: "hard"
    add_column :user_resource_criteria, :name, :string
    add_column :user_resource_criteria, :description, :text
    add_column :user_resource_criteria, :ai_instruction, :text

    execute <<~SQL.squish
      UPDATE user_resource_criteria
      SET name = COALESCE(name, text),
          ai_instruction = COALESCE(ai_instruction, text)
      WHERE name IS NULL OR ai_instruction IS NULL
    SQL

    change_column_null :user_resource_criteria, :name, false
    change_column_null :user_resource_criteria, :ai_instruction, false

    add_index :user_resource_criteria, [:projekt_phase_id, :kind, :position],
      name: "idx_urc_phase_kind_position"
  end

  def down
    remove_index :user_resource_criteria, name: "idx_urc_phase_kind_position"
    remove_column :user_resource_criteria, :ai_instruction
    remove_column :user_resource_criteria, :description
    remove_column :user_resource_criteria, :name
    remove_column :user_resource_criteria, :kind
  end
end
