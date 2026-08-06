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
    welcome: "welcome",
    unsupported: "unsupported"
  }

  # Delivery lifecycle, lowest to highest. "failed" outranks the successful
  # stages so a late delivery receipt cannot erase a recorded failure.
  STATUS_RANK = {
    "sent" => 1,
    "delivered" => 2,
    "read" => 3,
    "failed" => 4
  }.freeze

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

  # Anything that left the system counts as delivered for broadcast purposes:
  # matching "sent" alone would re-send to everyone whose delivery receipt has
  # since moved the row on to "delivered" or "read".
  def self.broadcast_delivered?(account_id, projekt_id)
    where(
      whatsapp_account_id: account_id,
      projekt_id: projekt_id,
      kind: "template",
      direction: "outbound"
    ).where.not(status: "failed").exists?
  end

  # Status webhooks arrive at least once and out of order, so only a later stage
  # of the lifecycle may overwrite the one already recorded.
  def apply_status!(new_status, errors: nil)
    return if !advances_to?(new_status)

    update!(status: new_status, error: errors.to_a.first.to_h)
  end

  private

    def advances_to?(new_status)
      STATUS_RANK.fetch(new_status, 0) > STATUS_RANK.fetch(status, 0)
    end
end
