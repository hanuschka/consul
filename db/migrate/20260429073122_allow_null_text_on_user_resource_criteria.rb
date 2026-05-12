class AllowNullTextOnUserResourceCriteria < ActiveRecord::Migration[6.1]
  def up
    change_column_null :user_resource_criteria, :text, true
  end

  def down
    execute <<~SQL.squish
      UPDATE user_resource_criteria
      SET text = COALESCE(text, name, ai_instruction, '')
      WHERE text IS NULL
    SQL

    change_column_null :user_resource_criteria, :text, false
  end
end
