class Whatsapp::Steps::NotificationSettingsService < ApplicationService
  MAX_SHOWN = 5

  # What the citizen currently receives and how to change it. Turning messages
  # off is offered as a button rather than left to the keyword list: STOPP is
  # the only phrasing the keyword matcher recognises, and someone who writes
  # "keine Nachrichten mehr" deserves the same answer.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.buttons(
      account: account,
      body: body,
      buttons: buttons
    )
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def user
      account.user
    end

    def opted_out?
      account.opt_out_at.present?
    end

    def body
      [state_line, followed_lines].compact_blank.join("\n\n")
    end

    def state_line
      return I18n.t("whatsapp.bot.menu.notifications.state_off") if opted_out?

      I18n.t("whatsapp.bot.menu.notifications.state_on")
    end

    def followed_lines
      return I18n.t("whatsapp.bot.menu.notifications.no_follows") if followed_projekts.empty?

      titles = followed_projekts.first(MAX_SHOWN).map do |projekt|
        "• #{Whatsapp::ProjektLink.title(projekt)}"
      end

      [I18n.t("whatsapp.bot.menu.notifications.follows"), *titles].join("\n")
    end

    def followed_projekts
      @followed_projekts ||= Whatsapp::FollowedProjektsQuery.call(user: user)
    end

    def buttons
      [toggle_button, menu_button]
    end

    def toggle_button
      action = opted_out? ? :messages_on : :messages_off

      {
        id: Whatsapp::NotificationActions::BUTTON_IDS.fetch(action),
        title: I18n.t("whatsapp.bot.buttons.#{action}")
      }
    end

    def menu_button
      {
        id: Whatsapp::Outbound::RECOVERY_ACTION_IDS.fetch(:menu),
        title: I18n.t("whatsapp.bot.buttons.menu")
      }
    end
end
