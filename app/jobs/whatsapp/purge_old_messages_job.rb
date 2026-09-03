class Whatsapp::PurgeOldMessagesJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::BULK_PRIORITY

  def perform
    purge_messages
    purge_webhook_events
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
end
