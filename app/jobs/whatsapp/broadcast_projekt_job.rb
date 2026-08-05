class Whatsapp::BroadcastProjektJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50
  BATCH_INTERVAL = 20.seconds

  def perform(projekt_id)
    projekt = Projekt.find_by(id: projekt_id)

    return if projekt.blank?
    return if !::Whatsapp.enabled?
    return if ::Whatsapp.broadcast_template_name.blank?

    enqueue_batches(projekt)
  end

  private

    def enqueue_batches(projekt)
      batch_count = 0

      WhatsappAccount.subscribed.pluck(:id).each_slice(BATCH_SIZE) do |account_ids|
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
