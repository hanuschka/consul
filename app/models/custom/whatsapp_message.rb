class WhatsappMessage < ApplicationRecord
  belongs_to :whatsapp_account
  belongs_to :projekt, optional: true

  enum direction: {
    inbound: "inbound",
    outbound: "outbound"
  }

  enum kind: {
    text: "text",
    audio: "audio",
    interactive: "interactive",
    template: "template",
    unsupported: "unsupported"
  }

  scope :older_than, ->(timestamp) { where(created_at: ...timestamp) }

  def self.inbound_recorded?(wa_message_id)
    return false if wa_message_id.blank?

    exists?(wa_message_id: wa_message_id, direction: "inbound")
  end

  def self.record_outbound!(account:, kind:, body:, response:, projekt_id: nil)
    create!(
      whatsapp_account: account,
      direction: "outbound",
      kind: kind,
      body: body,
      projekt_id: projekt_id,
      wa_message_id: response.message_id,
      status: response.success? ? "sent" : "failed",
      sent_at: Time.current,
      error: response.success? ? {} : response.error_payload
    )
  end

  def self.broadcast_delivered?(account_id, projekt_id)
    where(
      whatsapp_account_id: account_id,
      projekt_id: projekt_id,
      kind: "template",
      direction: "outbound",
      status: "sent"
    ).exists?
  end
end
