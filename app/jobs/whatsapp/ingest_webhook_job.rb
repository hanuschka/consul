class Whatsapp::IngestWebhookJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::REPLY_PRIORITY

  def perform(whatsapp_webhook_event_id)
    Whatsapp::Inbound::IngestWebhookService.call(event_id: whatsapp_webhook_event_id)
  end
end
