class ChangeStatusToStringInProjektPhaseStatQuestions < ActiveRecord::Migration[6.1]
  def up
    change_column :projekt_phase_stat_questions, :status, :string, default: "pending", null: false

    execute <<-SQL
      UPDATE projekt_phase_stat_questions
      SET status = CASE status
        WHEN '0' THEN 'pending'
        WHEN '1' THEN 'processing'
        WHEN '2' THEN 'completed'
        WHEN '3' THEN 'failed'
        ELSE 'pending'
      END
    SQL
  end

  def down
    execute <<-SQL
      UPDATE projekt_phase_stat_questions
      SET status = CASE status
        WHEN 'pending' THEN '0'
        WHEN 'processing' THEN '1'
        WHEN 'completed' THEN '2'
        WHEN 'failed' THEN '3'
        ELSE '0'
      END
    SQL

    change_column :projekt_phase_stat_questions, :status, :integer, default: 0, null: false
  end
end
