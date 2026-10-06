class Whatsapp::PurgeOldMessagesJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::BULK_PRIORITY

  CHAT_MEMORY_KEYS = %w[ai_chat ai_chain].freeze

  def perform
    purge_messages
    purge_webhook_events
    purge_idle_chat_memory
  end

  private

    def purge_messages
      cutoff = ::Whatsapp.retention_days.days.ago
      purged_count = Whatsapp::Message.older_than(cutoff).delete_all

      Rails.logger.info("[Whatsapp] purged #{purged_count} messages older than #{cutoff.to_date}")
    end

    # Raw payloads duplicate the message bodies and only exist to replay a
    # failed ingestion, so they are dropped long before the messages themselves.
    def purge_webhook_events
      cutoff = ::Whatsapp::WEBHOOK_EVENT_RETENTION.ago
      purged_count = Whatsapp::WebhookEvent.older_than(cutoff).delete_all

      Rails.logger.info(
        "[Whatsapp] purged #{purged_count} webhook events older than #{cutoff.to_date}"
      )
    end

    # The assistant's replayed history lives in the conversation's context, not in
    # Whatsapp::Message rows, so the message purge never reached it. Cleared once
    # the citizen has written nothing for the whole retention period, which is what
    # the assistant tells a citizen who asks how long the chat is kept.
    def purge_idle_chat_memory
      cutoff = ::Whatsapp.retention_days.days.ago
      idle_conversations =
        Whatsapp::Conversation
          .where(last_inbound_at: ...cutoff)
          .or(Whatsapp::Conversation.where(last_inbound_at: nil, updated_at: ...cutoff))
      cleared_count =
        idle_conversations
          .where("jsonb_exists_any(context, ARRAY[:keys])", keys: CHAT_MEMORY_KEYS)
          .update_all(["context = context - ARRAY[:keys]::text[]", { keys: CHAT_MEMORY_KEYS }])

      Rails.logger.info(
        "[Whatsapp] cleared chat memory of #{cleared_count} conversations idle since " \
        "#{cutoff.to_date}"
      )
    end
end
