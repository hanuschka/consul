class Whatsapp::IngestWebhookJob < ApplicationJob
  queue_as :default

  def perform(payload)
    Whatsapp::IngestWebhookService.call(payload: payload)
  end
end
