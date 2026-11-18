class Sms::Gateway
  ADAPTERS = {
    "esendex" => "Sms::Adapters::Esendex",
    "log" => "Sms::Adapters::Log"
  }.freeze

  def self.deliver(to:, text:)
    adapter_class = ADAPTERS[provider]
    result = if adapter_class
               adapter_class.constantize.new(config).deliver(to: to, text: text)
             else
               Sms::Result.failure("SMS provider not configured: #{provider.inspect}")
             end

    report_failure(result) unless result.success?
    result
  end

  def self.provider
    config[:provider].presence || ("log" if Rails.env.development? || Rails.env.test?)
  end

  def self.config
    (Rails.application.secrets.sms || {}).to_h.with_indifferent_access
  end

  def self.report_failure(result)
    message = "SMS delivery via #{provider || "none"} failed: #{result.error}"
    Rails.logger.error("[SMS] #{message}")
    Sentry.capture_message(message, level: :error)
  end
end
