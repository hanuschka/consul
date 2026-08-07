class Whatsapp::BroadcastProjektJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50
  BATCH_INTERVAL = 20.seconds

  def perform(projekt_id)
    projekt = Projekt.find_by(id: projekt_id)

    return if projekt.blank?
    return if !::Whatsapp.enabled?
    return if ::Whatsapp.broadcast_template_name.blank?
    return if already_broadcast?(projekt)
    return if !Whatsapp::BroadcastGuards.still_published?(projekt, context: "broadcast")

    enqueue_batches(projekt)

    projekt.mark_whatsapp_broadcast_sent!
  end

  private

    # Guards every path into the broadcast at once: the automatic trigger on
    # publication, its cascade onto child projekts, and a second publication
    # inside PUBLICATION_BROADCAST_DELAY. Staff who deliberately re-send from
    # the projekt page clear the marker first, so their click still gets
    # through.
    def already_broadcast?(projekt)
      return false if !projekt.whatsapp_broadcast_sent_for_current_slug?

      Rails.logger.info(
        "[Whatsapp] broadcast for projekt #{projekt.id} skipped: already sent " \
        "at #{projekt.whatsapp_broadcast_sent_at}"
      )

      true
    end

    def enqueue_batches(projekt)
      batch_count = 0

      Whatsapp::Account.subscribed_to(:new_projekt).pluck(:id).each_slice(BATCH_SIZE) do |account_ids|
        Whatsapp::BroadcastProjektBatchJob
          .set(wait: batch_count * BATCH_INTERVAL)
          .perform_later(projekt.id, account_ids)

        batch_count += 1
      end

      Rails.logger.info(
        "[Whatsapp] broadcast for projekt #{projekt.id} split into #{batch_count} batches"
      )
    end
end
