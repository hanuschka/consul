class AiProposalFlow::AiLoaderComponent < ApplicationComponent
  def initialize(message_key:, submessage_key:)
    @message_key = message_key
    @submessage_key = submessage_key
  end

  private

    attr_reader :message_key, :submessage_key
end
