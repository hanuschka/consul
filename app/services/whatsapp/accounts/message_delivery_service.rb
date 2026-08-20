class Whatsapp::Accounts::MessageDeliveryService < ApplicationService
  # The one place the opt-in state is written, reached from the typed keywords and
  # from the assistant's stop_messages tool. Split into two entry points because
  # the two answers share nothing.
  #
  # This is the one reply the assistant does not get to write. Leaving the channel
  # must not depend on a model being reachable, so both the write and the sentence
  # confirming it stay on the locale copy — the same reason the keyword gate sits
  # above the assistant in the inbound chain.
  def self.enable(conversation:)
    new(conversation: conversation).turn_on
  end

  def self.disable(conversation:)
    new(conversation: conversation).turn_off
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  # Coming back is the one of the two that has somewhere to go next, so it carries
  # the way in. Its label is the recovery copy's rather than the assistant's for the
  # same reason the sentence is: the opt-in is written before the send and this path
  # sits above the assistant, so there is no turn whose words the label could be.
  def turn_on
    account.opt_in!

    ::Whatsapp::Send.recovery(
      conversation: @conversation, body: I18n.t("whatsapp.bot.opted_in"), actions: [:help]
    )
  end

  # Opting out also drops whatever draft was open: a citizen asking not to be
  # written to should not be left mid-submission waiting for an answer they said
  # they do not want. Nothing is offered afterwards either — the last thing
  # someone who just opted out needs is an invitation to carry on.
  def turn_off
    account.opt_out!
    @conversation.discard_draft!

    send_bot_line(I18n.t("whatsapp.bot.compliance.opted_out"))
  end

  private

    # The sentence stays the locale copy's rather than the assistant's, for the reason
    # above; which language it reaches the citizen in is a separate question, and the
    # answer to it is the one they wrote in.
    def send_bot_line(body)
      ::Whatsapp::Send.locale_text(account: account, body: body)
    end

    def account
      @conversation.whatsapp_account
    end
end
