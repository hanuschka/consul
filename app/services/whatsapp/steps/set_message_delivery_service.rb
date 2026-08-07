class Whatsapp::Steps::SetMessageDeliveryService < ApplicationService
  # The same state the STOPP and START keywords write, reachable from a button
  # and from the assistant. Opting out also drops whatever flow was open: a
  # citizen asking not to be written to should not be left mid-submission
  # waiting for an answer they said they do not want.
  def initialize(conversation:, enabled:)
    @conversation = conversation
    @enabled = enabled
  end

  def call
    return turn_on if @enabled

    turn_off
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def turn_on
      account.update!(opt_in_at: Time.current, opt_out_at: nil)

      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.opted_in"),
        actions: [:menu]
      )
    end

    # No menu button: the last thing someone who just opted out needs is an
    # invitation to carry on.
    def turn_off
      account.update!(opt_out_at: Time.current)
      @conversation.reset_flow!

      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.opted_out"))
    end
end
