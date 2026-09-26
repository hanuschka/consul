module Whatsapp::BroadcastGuards
  module_function

  # Publication is re-checked live rather than trusted from enqueue time: the
  # automatic broadcast waits PUBLICATION_BROADCAST_DELAY, which is exactly the
  # window in which a projekt published by mistake gets deactivated again.
  # Criteria are read from the projekt itself, so a page taken back to draft
  # counts too, even though that leaves `published_at` stale.
  #
  # Asked again per batch, not only once by the fan-out: the batches are spread
  # over BATCH_INTERVAL each, so the last of them can run long after the first.
  def still_published?(projekt, context:)
    return true if projekt.meets_publish_criteria?

    Rails.logger.info(
      "[Whatsapp] #{context} for projekt #{projekt.id} skipped: no longer published"
    )

    false
  end
end
