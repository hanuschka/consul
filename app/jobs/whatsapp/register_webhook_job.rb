class Whatsapp::RegisterWebhookJob < ApplicationJob
  queue_as :default

  def perform(base_url = nil)
    Whatsapp::Platform::RegisterWebhookService.call(base_url: base_url)
  end
end
