class Whatsapp::SendLinkConfirmationService < ApplicationService
  def initialize(account:)
    @account = account
  end

  def call
    Whatsapp::SendTextService.call(
      account: @account,
      body: I18n.t("whatsapp.bot.link_confirmed", name: @account.user.name)
    )

    Whatsapp::ResumeFlowService.call(conversation: @account.conversation)
  end
end
