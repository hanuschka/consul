class Sms::Result
  attr_reader :message_id, :error

  def self.success(message_id: nil)
    new(success: true, message_id: message_id)
  end

  def self.failure(error)
    new(success: false, error: error)
  end

  def initialize(success:, message_id: nil, error: nil)
    @success = success
    @message_id = message_id
    @error = error
  end

  def success?
    @success
  end
end
