class WhatsappApi::WebhooksController < WhatsappApi::BaseController
  def create
    ::Whatsapp::IngestWebhookJob.perform_later(request.request_parameters)

    head :ok
  end
end
