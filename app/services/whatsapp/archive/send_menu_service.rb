class Whatsapp::Archive::SendMenuService < ApplicationService
  # Renders any of the three menus — portal, projekt, phase — from the section
  # map in ::Whatsapp::Archive::MenuActions plus a caller that says which actions are
  # actually worth offering right now. An action with nothing behind it is left
  # out rather than shown and then apologised for.
  #
  # `empty_body` is what to say when there are no rows at all. A caller whose
  # body is a confirmation passes it here too, so an empty portal answers with
  # that message rather than swallowing it for the generic "nothing open" copy.
  def initialize(conversation:, scope:, body:, available_actions:, record_id: 0, empty_body: nil)
    @conversation = conversation
    @scope = scope
    @body = body
    @available_actions = available_actions
    @record_id = record_id
    @empty_body = empty_body
  end

  def call
    return send_nothing_available if sections.empty?

    Whatsapp::Outbound.sectioned_list(
      account: @conversation.whatsapp_account,
      body: @body,
      button_label: I18n.t("whatsapp.archive.menu.button"),
      sections: sections
    )
  end

  private

    def sections
      @sections ||=
        ::Whatsapp::Archive::MenuActions.sections_for(@scope).filter_map do |section_key, actions|
          rows = rows_for(actions)

          next if rows.empty?

          { title: I18n.t("whatsapp.archive.menu.sections.#{section_key}"), rows: rows }
        end
    end

    def rows_for(actions)
      actions.select { |action| @available_actions.include?(action) }.map do |action|
        {
          id: ::Whatsapp::Archive::MenuActions.id_for(scope: @scope, action: action, record_id: @record_id),
          title: I18n.t("whatsapp.archive.menu.rows.#{@scope}.#{action}.title"),
          description: I18n.t("whatsapp.archive.menu.rows.#{@scope}.#{action}.description")
        }
      end
    end

    # The portal menu's own dead end falls back to plain text: offering the
    # portal menu here would only redraw the same empty menu. A projekt or phase
    # menu with nothing in it still has somewhere to go, so it hands over to the
    # portal.
    def send_nothing_available
      return send_text if @scope == :portal

      ::Whatsapp::Archive::MainMenuService.call(
        conversation: @conversation,
        body: I18n.t("whatsapp.archive.menu.nothing_here")
      )
    end

    def send_text
      Whatsapp::Outbound.text(
        account: @conversation.whatsapp_account,
        body: @empty_body.presence || I18n.t("whatsapp.bot.no_projekt")
      )
    end
end
