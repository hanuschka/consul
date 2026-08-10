class Whatsapp::Inbound::IngestWebhookService < ApplicationService
  KIND_BY_MESSAGE_TYPE = {
    "text" => "text",
    "audio" => "audio",
    "image" => "image",
    "voice" => "audio",
    "interactive" => "interactive",
    "button" => "interactive",
    "request_welcome" => "welcome"
  }.freeze

  def initialize(event_id:)
    @event_id = event_id
  end

  def call
    return if event.blank?

    change_values.each do |value|
      record_statuses(value["statuses"])
      record_messages(value["messages"], value["contacts"])
    end

    event.mark_processed!
  end

  private

    def event
      return @event if defined?(@event)

      @event = Whatsapp::WebhookEvent.find_by(id: @event_id)
    end

    def payload
      event.payload.to_h
    end

    def change_values
      values = Array(payload["entry"]).flat_map do |entry|
        Array(entry["changes"]).map { |change| change["value"].to_h }
      end

      values.select { |value| whatsapp_value?(value) }
    end

    # The v1 payloads 360dialog forwards carry no messaging_product; a present
    # one that names another product belongs to a different integration.
    def whatsapp_value?(value)
      product = value["messaging_product"]

      product.blank? || product == "whatsapp"
    end

    def record_statuses(statuses)
      Array(statuses).each do |status|
        message = Whatsapp::Message.find_by(wa_message_id: status["id"], direction: "outbound")

        next if message.blank?

        message.apply_status!(status["status"], errors: status["errors"])
      end
    end

    def record_messages(messages, contacts)
      Array(messages).each do |message|
        record_message(message, contacts)
      end
    end

    # One failing message must never abort the rest of the batch: 360dialog
    # retries deliveries, so a concurrent retry can lose the unique-index race
    # while other messages in the same payload are still new.
    def record_message(message, contacts)
      return if Whatsapp::Message.inbound_recorded?(message["id"])

      account = find_or_create_account(message["from"], contacts)
      inbound_message = persist_message(account, message)

      # WhatsApp measures the 24-hour window from when the citizen sent the
      # message, not from when we received it. A delivery retried hours later
      # would otherwise reopen the window on our side while it stays shut on
      # theirs, and the reply comes back as error 131047.
      # Only ever forwards. Deliveries arrive out of order and get retried, and
      # an older timestamp written over a newer one would shut the window while
      # the citizen is still inside it, silently dropping every reply.
      account.update!(last_inbound_at: latest_inbound_at(account, message))

      Whatsapp::ProcessInboundMessageJob.perform_later(inbound_message.id, message)
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.info("[Whatsapp] duplicate delivery for #{message['id']} ignored")
    rescue StandardError => e
      Rails.logger.error("[Whatsapp] ingest failed for #{message['id']}: #{e.class} - #{e.message}")
      Sentry.capture_exception(e, extra: { wa_message_id: message["id"] })
    end

    def find_or_create_account(wa_id, contacts)
      account = Whatsapp::Account.find_or_initialize_by(wa_id: wa_id)
      account.phone ||= wa_id
      account.profile_name = profile_name_for(wa_id, contacts) || account.profile_name
      account.save!

      account
    end

    def profile_name_for(wa_id, contacts)
      contact = Array(contacts).find { |candidate| candidate["wa_id"] == wa_id }

      contact.to_h.dig("profile", "name")
    end

    def persist_message(account, message)
      Whatsapp::Message.create!(
        whatsapp_account: account,
        direction: "inbound",
        kind: KIND_BY_MESSAGE_TYPE.fetch(message["type"], "unsupported"),
        body: inbound_body(message),
        wa_message_id: message["id"],
        status: "received",
        sent_at: inbound_sent_at(message)
      )
    end

    def inbound_body(message)
      case message["type"]
      when "text"
        message.dig("text", "body")
      when "interactive"
        message.dig("interactive", "button_reply", "title") ||
          message.dig("interactive", "list_reply", "title")
      when "button"
        message.dig("button", "text")
      end
    end

    def latest_inbound_at(account, message)
      [inbound_sent_at(message) || Time.current, account.last_inbound_at].compact.max
    end

    def inbound_sent_at(message)
      timestamp = message["timestamp"].to_i

      return if timestamp.zero?

      Time.zone.at(timestamp)
    end
end
