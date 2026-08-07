class Whatsapp::Steps::SendProjektCardService < ApplicationService
  SUMMARY_LENGTH = 300

  # What a tapped projekt row answers with. WhatsApp will not carry a URL button
  # and reply buttons in the same message — cta_url and button are different
  # interactive types — so the link goes in the body, where WhatsApp makes it
  # tappable anyway, and all three buttons stay available.
  def initialize(conversation:, projekt:)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: body,
      buttons: buttons
    )
  end

  private

    def user
      @conversation.whatsapp_account.user
    end

    def body
      [
        "*#{Whatsapp::ProjektLink.title(@projekt)}*",
        subtitle,
        Whatsapp::ProjektLink.url(@projekt)
      ].compact_blank.join("\n\n")
    end

    def subtitle
      @projekt.page&.subtitle.presence&.squish&.truncate(SUMMARY_LENGTH)
    end

    # Three is the hard limit, so the follow button is what gives way when the
    # number is not linked to an account and following is not possible yet.
    def buttons
      [menu_button, follow_button, home_button].compact.first(3)
    end

    def menu_button
      {
        id: Whatsapp::MenuActions.id_for(scope: :projekt, action: :menu, record_id: @projekt.id),
        title: I18n.t("whatsapp.bot.buttons.projekt_menu")
      }
    end

    def follow_button
      return if user.blank?

      following = Whatsapp::ToggleProjektFollowService.following?(user: user, projekt: @projekt)

      {
        id: Whatsapp::MenuActions.id_for(scope: :projekt, action: :follow, record_id: @projekt.id),
        title: I18n.t("whatsapp.bot.buttons.#{following ? "unfollow" : "follow"}")
      }
    end

    def home_button
      {
        id: Whatsapp::Outbound::RECOVERY_ACTION_IDS.fetch(:menu),
        title: I18n.t("whatsapp.bot.buttons.menu")
      }
    end
end
