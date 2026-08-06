class Whatsapp::RegisterWebhookJob < ApplicationJob
  queue_as :default

  def perform(base_url = nil)
    Whatsapp::RegisterWebhookService.call(base_url: base_url)
  end
end
