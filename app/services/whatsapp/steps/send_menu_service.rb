class Whatsapp::Steps::SendMenuService < ApplicationService
  # Renders any of the three menus — portal, projekt, phase — from the section
  # map in Whatsapp::MenuActions plus a caller that says which actions are
  # actually worth offering right now. An action with nothing behind it is left
  # out rather than shown and then apologised for.
  def initialize(conversation:, scope:, body:, available_actions:, record_id: 0)
    @conversation = conversation
    @scope = scope
    @body = body
    @available_actions = available_actions
    @record_id = record_id
  end

  def call
    return send_nothing_available if sections.empty?

    Whatsapp::Outbound.sectioned_list(
      account: @conversation.whatsapp_account,
      body: @body,
      button_label: I18n.t("whatsapp.bot.menu.button"),
      sections: sections
    )
  end

  private

    def sections
      @sections ||=
        Whatsapp::MenuActions.sections_for(@scope).filter_map do |section_key, actions|
          rows = rows_for(actions)

          next if rows.empty?

          { title: I18n.t("whatsapp.bot.menu.sections.#{section_key}"), rows: rows }
        end
    end

    def rows_for(actions)
      actions.select { |action| @available_actions.include?(action) }.map do |action|
        {
          id: Whatsapp::MenuActions.id_for(scope: @scope, action: action, record_id: @record_id),
          title: I18n.t("whatsapp.bot.menu.rows.#{@scope}.#{action}.title"),
          description: I18n.t("whatsapp.bot.menu.rows.#{@scope}.#{action}.description")
        }
      end
    end

    # No menu button on the portal menu's own dead end: it would only redraw the
    # same empty menu.
    def send_nothing_available
      return send_text if @scope == :portal

      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.nothing_here"),
        actions: [:menu]
      )
    end

    def send_text
      Whatsapp::Outbound.text(
        account: @conversation.whatsapp_account,
        body: I18n.t("whatsapp.bot.no_projekt")
      )
    end
end
