class Whatsapp::Flows::HelpService < Whatsapp::Flows::BaseService
  # Catalog E32. Everything the bot does, reachable at any time.
  #
  # It was one sentence of prose naming four capabilities, which had stopped
  # being true and gave no way to start any of them. A list makes each one a
  # tap, and a tap lands in exactly the same place as saying the words would —
  # the rows carry catalog actions, not a menu of their own.
  #
  # It adapts to whether the number is linked: offering "unlink your account" to
  # someone who never linked one contradicts the invitation they were just sent,
  # and offering "link now" to someone already linked is noise.
  ROWS = {
    submit: :submit_proposal,
    support: :support_prompt,
    comment: :comment_prompt,
    projekts: :discover,
    contributions: :my_contributions,
    notifications: :notifications_open
  }.freeze

  LINKED_ROW = { unlink: :unlink_start }.freeze
  UNLINKED_ROW = { link: :link_yes }.freeze

  # Two rows name the same thing as the button that starts it elsewhere, so
  # they read that button's label rather than carrying a second copy of the
  # word. The Vorschlag/Beitrag rename had to touch both copies; the next one
  # would have renamed the button and left the list naming the same action
  # differently.
  SHARED_TITLE_KEYS = {
    submit: "whatsapp.bot.buttons.submit_proposal",
    contributions: "whatsapp.bot.buttons.my_contributions"
  }.freeze

  def call
    Whatsapp::Send.list(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.help_menu.body"),
      button_label: I18n.t("whatsapp.bot.buttons.choose_help"),
      rows: rows
    )
  end

  private

    def rows
      ROWS.merge(account_row).map { |key, action| list_row(key, action) }
    end

    def account_row
      account.user_id.present? ? LINKED_ROW : UNLINKED_ROW
    end

    def list_row(key, action)
      {
        id: Whatsapp::FlowActions.id_for(action: action),
        title: I18n.t(title_key_for(key)),
        description: I18n.t("whatsapp.bot.help_menu.rows.#{key}.description")
      }
    end

    def title_key_for(key)
      SHARED_TITLE_KEYS.fetch(key, "whatsapp.bot.help_menu.rows.#{key}.title")
    end
end
