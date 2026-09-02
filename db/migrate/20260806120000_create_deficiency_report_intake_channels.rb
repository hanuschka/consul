class CreateDeficiencyReportIntakeChannels < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_intake_channels do |t|
      t.integer :given_order
      t.boolean :default, default: false, null: false

      t.timestamps
    end

    add_reference :deficiency_reports, :deficiency_report_intake_channel,
      foreign_key: true, index: { name: "index_deficiency_reports_on_intake_channel_id" }

    reversible do |dir|
      dir.up do
        DeficiencyReport::IntakeChannel.create_translation_table! name: :string
      end

      dir.down do
        DeficiencyReport::IntakeChannel.drop_translation_table!
      end
    end
  end
end
