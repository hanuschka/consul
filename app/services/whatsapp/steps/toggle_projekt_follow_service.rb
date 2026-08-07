class Whatsapp::Steps::ToggleProjektFollowService < ApplicationService
  def initialize(conversation:, projekt:)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    return send_link_invitation if user.blank?

    outcome = Whatsapp::ToggleProjektFollowService.call(user: user, projekt: @projekt)

    Whatsapp::Steps::MainMenuService.call(
      conversation: @conversation,
      body: I18n.t(
        "whatsapp.bot.menu.follow.#{outcome}",
        projekt: Whatsapp::ProjektLink.title(@projekt)
      )
    )
  end

  private

    def user
      @conversation.user
    end

    def send_link_invitation
      Whatsapp::Steps::SendLinkInvitationService.call(conversation: @conversation)
    end
end
