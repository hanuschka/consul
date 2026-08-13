class Whatsapp::Flows::NotificationSettingsService < Whatsapp::Flows::BaseService
  # Catalog B12-extended. Six independent switches and a Done row.
  #
  # WhatsApp list rows carry no state of their own, so a "toggle" is really
  # re-sending the whole list with one glyph changed. That is the interaction
  # model, not a workaround: the citizen taps, the list comes back showing what
  # they just did, and "Done" ends it.
  #
  # The glyph leads the title because a row title is capped at 24 characters and
  # the catalog's full sentences do not fit — they are the row description,
  # which has 72. Truncating the label instead would hide which switch is which.
  ON_GLYPH = "✅".freeze
  OFF_GLYPH = "⬜".freeze
  DONE_ROW_ID = "#{Whatsapp::FlowActions::PREFIX}notifications_done".freeze

  def self.toggle(conversation:, type:)
    new(conversation: conversation).toggle(type)
  end

  # One tap on one row of the settings list. Flips the column and re-sends the
  # list so the citizen sees the glyph they just changed — the list itself is
  # the only feedback WhatsApp can give here.
  def toggle(type)
    notification_type = type.to_s.to_sym

    return if !Whatsapp::Account::NOTIFICATION_TYPES.include?(notification_type)

    account.toggle_notification!(notification_type)

    call
  end

  def call
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_NOTIFICATION_SETTINGS)

    Whatsapp::Outbound.list(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.notifications.settings_title"),
      button_label: I18n.t("whatsapp.bot.buttons.choose_notifications"),
      rows: rows
    )
  end

  private

    def rows
      type_rows << done_row
    end

    def type_rows
      Whatsapp::Account::NOTIFICATION_TYPES.map do |type|
        {
          id: Whatsapp::FlowActions.id_for(action: :notify_toggle, param: type),
          title: "#{glyph_for(type)} #{I18n.t("whatsapp.bot.notifications.types.#{type}.short")}",
          description: I18n.t("whatsapp.bot.notifications.types.#{type}.label")
        }
      end
    end

    def done_row
      { id: DONE_ROW_ID, title: I18n.t("whatsapp.bot.buttons.done") }
    end

    def glyph_for(type)
      account.notifies?(type) ? ON_GLYPH : OFF_GLYPH
    end
end
