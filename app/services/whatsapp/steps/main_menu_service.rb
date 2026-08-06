class Whatsapp::Steps::MainMenuService < ApplicationService
  # The central navigation: one flat list whose rows are the things the bot can
  # do, rather than the phase chooser that used to stand in for a menu. Rows
  # that lead nowhere are left out instead of shown and then apologised for, so
  # a portal with no open phase still offers reading rather than a dead end.
  ACTION_ORDER = %i[create contributions projekts results].freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return send_nothing_available if available_actions.empty?

    Whatsapp::Outbound.list(
      account: @conversation.whatsapp_account,
      body: ::Whatsapp.menu_greeting,
      button_label: I18n.t("whatsapp.bot.menu.button"),
      rows: rows
    )
  end

  private

    def rows
      available_actions.map do |action|
        {
          id: Whatsapp::MenuActions::ROW_IDS.fetch(action),
          title: I18n.t("whatsapp.bot.menu.rows.#{action}.title"),
          description: I18n.t("whatsapp.bot.menu.rows.#{action}.description")
        }
      end
    end

    def available_actions
      @available_actions ||= ACTION_ORDER.select { |action| available?(action) }
    end

    def available?(action)
      case action
      when :create then open_projekt_phases.any?
      when :contributions then contributions.any?
      when :projekts then browsable_projekts.any?
      when :results then published_results.any?
      end
    end

    def open_projekt_phases
      @open_projekt_phases ||= WhatsappEligiblePhasesQuery.call
    end

    def contributions
      @contributions ||= WhatsappUserContributionsQuery.call(user: @conversation.whatsapp_account.user)
    end

    def browsable_projekts
      @browsable_projekts ||= WhatsappBrowsableProjektsQuery.call
    end

    def published_results
      @published_results ||= WhatsappPublishedResultsQuery.call
    end

    # No menu button here: it would only redraw the same empty menu.
    def send_nothing_available
      Whatsapp::Outbound.text(
        account: @conversation.whatsapp_account,
        body: I18n.t("whatsapp.bot.no_projekt")
      )
    end
end
