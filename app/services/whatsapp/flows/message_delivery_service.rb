class Whatsapp::Flows::MessageDeliveryService < Whatsapp::Flows::BaseService
  # Catalog E34 and its inverse. The one place the opt-in state is written,
  # reachable from the STOP and START keywords and from the assistant. Split
  # into two entry points because the two answers share nothing.
  def self.enable(conversation:)
    new(conversation: conversation).turn_on
  end

  def self.disable(conversation:)
    new(conversation: conversation).turn_off
  end

  def turn_on
    account.opt_in!

    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.opted_in")
    )
  end

  # Opting out also drops whatever flow was open: a citizen asking not to be
  # written to should not be left mid-submission waiting for an answer they said
  # they do not want. Nothing is offered afterwards either — the last thing
  # someone who just opted out needs is an invitation to carry on.
  def turn_off
    account.opt_out!
    @conversation.reset_flow!

    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.compliance.opted_out")
    )
  end
end
