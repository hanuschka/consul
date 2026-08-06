class Whatsapp::IngestWebhookJob < ApplicationJob
  queue_as :default

  def perform(whatsapp_webhook_event_id)
    event = WhatsappWebhookEvent.find_by(id: whatsapp_webhook_event_id)

    return if event.blank?

    Whatsapp::IngestWebhookService.call(payload: event.payload)

    event.mark_processed!
  end
end
