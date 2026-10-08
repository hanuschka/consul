class ProjektContentBlocks::BulkWrite::InvalidRequestError < StandardError
  attr_reader :messages

  def initialize(messages)
    @messages = messages
    super(messages.values.flatten.join(", "))
  end
end
