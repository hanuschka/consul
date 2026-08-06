class Whatsapp::Steps::ListResultsService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return send_empty if projekt_phases.empty?

    Whatsapp::Outbound.list(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.menu.results.body"),
      button_label: I18n.t("whatsapp.bot.menu.results.button"),
      rows: rows
    )
  end

  private

    def projekt_phases
      @projekt_phases ||= WhatsappPublishedResultsQuery.call
    end

    # The projekt names the row because a citizen recognises the projekt, not
    # the phase; the phase and its end date go in the description.
    def rows
      projekt_phases.map do |projekt_phase|
        {
          id: Whatsapp::MenuActions.result_row_id_for(projekt_phase.id),
          title: projekt_title(projekt_phase.projekt),
          description: row_description(projekt_phase)
        }
      end
    end

    def row_description(projekt_phase)
      return projekt_phase.title if projekt_phase.end_date.blank?

      I18n.t(
        "whatsapp.bot.projekt_row_description",
        phase: projekt_phase.title,
        end_date: I18n.l(projekt_phase.end_date.to_date)
      )
    end

    def projekt_title(projekt)
      projekt.page&.title.presence || projekt.name
    end

    def send_empty
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.results.empty"),
        actions: [:menu]
      )
    end
end
