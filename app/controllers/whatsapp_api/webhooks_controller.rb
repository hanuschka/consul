class WhatsappApi::WebhooksController < WhatsappApi::BaseController
  # The raw payload is stored before anything is parsed: 360dialog has already
  # been answered by the time the job runs, so this row is the only copy left to
  # replay a delivery from if ingestion fails.
  def create
    event = Whatsapp::WebhookEvent.create!(payload: request.request_parameters)

    ::Whatsapp::IngestWebhookJob.perform_later(event.id)

    head :ok
  end
end
