class Sms::Adapters::Log
  cattr_accessor :deliveries, default: []

  def initialize(_config); end

  def deliver(to:, text:)
    Sms::Adapters::Log.deliveries << { to: to, text: text } if Rails.env.test?
    Rails.logger.info("[SMS] to #{to}: #{text}")
    Sms::Result.success(message_id: SecureRandom.uuid)
  end
end
