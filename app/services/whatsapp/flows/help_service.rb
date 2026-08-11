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
  ROWS = [
    { key: :submit, action: :submit_proposal },
    { key: :support, action: :support_prompt },
    { key: :comment, action: :comment_prompt },
    { key: :projekts, action: :discover },
    { key: :contributions, action: :my_contributions },
    { key: :notifications, action: :notifications_open }
  ].freeze

  LINKED_ROW = { key: :unlink, action: :unlink_start }.freeze
  UNLINKED_ROW = { key: :link, action: :link_yes }.freeze

  def call
    Whatsapp::Outbound.list(
      account: account,
      body: I18n.t("whatsapp.bot.help_menu.body"),
      button_label: I18n.t("whatsapp.bot.buttons.choose_help"),
      rows: rows
    )
  end

  private

    def rows
      (ROWS + [account_row]).map { |row| list_row(row) }
    end

    def account_row
      account.user_id.present? ? LINKED_ROW : UNLINKED_ROW
    end

    def list_row(row)
      {
        id: Whatsapp::FlowActions.id_for(action: row[:action]),
        title: I18n.t("whatsapp.bot.help_menu.rows.#{row[:key]}.title"),
        description: I18n.t("whatsapp.bot.help_menu.rows.#{row[:key]}.description")
      }
    end
end
