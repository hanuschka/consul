class Whatsapp::SendLinkInvitationService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    link_url = Whatsapp::LinkTokenService.call(account: account)
    @conversation.update!(step: "awaiting_link")

    Whatsapp::SendTextService.call(
      account: account,
      body: I18n.t("whatsapp.bot.link_invitation", url: link_url)
    )
  end

  private

    def account
      @conversation.whatsapp_account
    end
end
