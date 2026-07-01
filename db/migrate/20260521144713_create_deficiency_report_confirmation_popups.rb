class CreateDeficiencyReportConfirmationPopups < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_confirmation_popups do |t|
      t.boolean :enabled, null: false, default: false
      t.text :question
      t.timestamps
    end

    create_table :deficiency_report_confirmation_popup_answers do |t|
      t.references :confirmation_popup,
        null: false,
        index: { name: "index_dr_confirmation_popup_answers_on_popup_id" },
        foreign_key: { to_table: :deficiency_report_confirmation_popups, on_delete: :cascade }
      t.string :label
      t.integer :behavior, null: false, default: 0
      t.text :flash_notice
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
