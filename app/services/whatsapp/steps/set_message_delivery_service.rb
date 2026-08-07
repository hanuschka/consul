class Whatsapp::Steps::SetMessageDeliveryService < ApplicationService
  # The one place the opt-in state is written, reachable from the STOPP and
  # START keywords, from a recovery button and from the assistant. Split into
  # two entry points because the two answers share nothing: opting back in ends
  # with a menu button, opting out deliberately does not.
  def self.enable(conversation:)
    new(conversation: conversation).turn_on
  end

  def self.disable(conversation:)
    new(conversation: conversation).turn_off
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def turn_on
    account.opt_in!

    Whatsapp::Steps::MainMenuService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.opted_in")
    )
  end

  # Opting out also drops whatever flow was open: a citizen asking not to be
  # written to should not be left mid-submission waiting for an answer they
  # said they do not want. No menu button either — the last thing someone who
  # just opted out needs is an invitation to carry on.
  def turn_off
    account.opt_out!
    @conversation.reset_flow!

    Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.opted_out"))
  end

  private

    def account
      @conversation.whatsapp_account
    end
end
