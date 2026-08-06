class Whatsapp::IngestWebhookJob < ApplicationJob
  queue_as :default

  def perform(whatsapp_webhook_event_id)
    Whatsapp::IngestWebhookService.call(event_id: whatsapp_webhook_event_id)
  end
end
