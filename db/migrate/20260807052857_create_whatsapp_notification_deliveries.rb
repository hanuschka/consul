class CreateWhatsappNotificationDeliveries < ActiveRecord::Migration[6.1]
  # The deadline pushes are time-triggered, so a rerun of the daily job — after
  # a deploy, a retry, a clock change — would otherwise send the same reminder
  # twice. The unique index is what makes the job idempotent; the row is the
  # receipt.
  def change
    create_table :whatsapp_notification_deliveries do |t|
      t.bigint :whatsapp_account_id, null: false
      t.bigint :projekt_phase_id
      t.string :kind, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end

    add_index :whatsapp_notification_deliveries,
      [:whatsapp_account_id, :projekt_phase_id, :kind],
      unique: true,
      name: "index_whatsapp_notification_deliveries_on_account_phase_kind"
  end
end
