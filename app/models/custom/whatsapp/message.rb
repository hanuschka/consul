class Whatsapp::Message < ApplicationRecord
  belongs_to :whatsapp_account, class_name: "Whatsapp::Account", inverse_of: :whatsapp_messages
  belongs_to :projekt, class_name: "::Projekt", optional: true

  enum direction: {
    inbound: "inbound",
    outbound: "outbound"
  }

  enum kind: {
    text: "text",
    audio: "audio",
    image: "image",
    interactive: "interactive",
    location: "location",
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

  # The id of the last message this number sent us, which is the only message WhatsApp
  # will hang a typing indicator on. Asked for where a reply is owed without an inbound
  # message having triggered it — a vote that finished on a tap two services down, a
  # login link followed in a browser — so the bubble goes on the message the citizen is
  # actually looking at.
  #
  # Ordered by id rather than by created_at: the rows are written as the messages
  # arrive, so the newest is the highest id, and the primary key is an index the
  # timestamp ordering would not use.
  def self.latest_inbound_id(account:)
    where(whatsapp_account_id: account.id, direction: "inbound")
      .order(id: :desc)
      .pick(:wa_message_id)
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

  # A send refused before it was attempted, recorded as the failure it is. The
  # distinction it keeps is the one every caller already reads: nil means nothing
  # could be delivered and there is nothing to do differently — a closed service
  # window — where this is a message composed wrong, which the caller's own error
  # path is for. No wa_message_id and no sent_at, because WhatsApp never saw it.
  def self.record_unsent!(account:, kind:, body:, error:, projekt_id: nil)
    create!(
      whatsapp_account: account,
      direction: "outbound",
      kind: kind,
      body: body,
      projekt_id: projekt_id,
      status: "failed",
      error: error
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
