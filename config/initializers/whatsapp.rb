Rails.application.config.after_initialize do
  Whatsapp.report_webhook_authentication
end
