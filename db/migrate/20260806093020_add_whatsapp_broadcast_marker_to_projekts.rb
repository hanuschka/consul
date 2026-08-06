class AddWhatsappBroadcastMarkerToProjekts < ActiveRecord::Migration[6.1]
  def change
    add_column :projekts, :whatsapp_broadcast_sent_at, :datetime
    add_column :projekts, :whatsapp_broadcast_slug, :string
  end
end
