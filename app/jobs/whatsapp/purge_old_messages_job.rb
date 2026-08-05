class Whatsapp::PurgeOldMessagesJob < ApplicationJob
  queue_as :default

  def perform
    cutoff = ::Whatsapp.retention_days.days.ago
    purged_count = WhatsappMessage.older_than(cutoff).delete_all

    Rails.logger.info("[Whatsapp] purged #{purged_count} messages older than #{cutoff.to_date}")
  end
end
