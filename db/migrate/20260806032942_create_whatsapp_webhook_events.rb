class CreateWhatsappWebhookEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :whatsapp_webhook_events do |t|
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :whatsapp_webhook_events, :created_at
    add_index :whatsapp_webhook_events, :processed_at
  end
end
