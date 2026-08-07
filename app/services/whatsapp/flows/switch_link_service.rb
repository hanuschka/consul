class Whatsapp::Flows::SwitchLinkService < ApplicationService
  # The way out of a refused :number_taken confirmation. Releasing a linkage
  # someone else made is safe only from here: the pill that reaches this service
  # can be tapped by nobody but the citizen holding the phone the number belongs
  # to, whereas the link page is opened by whoever happens to have the URL.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.whatsapp_account.unlink!

    Whatsapp::Flows::SendLoginLinkService.call(conversation: @conversation)
  end
end
