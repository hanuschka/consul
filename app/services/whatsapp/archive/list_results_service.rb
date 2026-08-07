class Whatsapp::Archive::ListResultsService < ApplicationService
  def initialize(conversation:, projekt: nil)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    ::Whatsapp::Flows::SendListService.call(
      conversation: @conversation,
      rows: rows,
      body: I18n.t("whatsapp.archive.menu.results.body"),
      button_label: I18n.t("whatsapp.archive.menu.results.button"),
      empty_body: I18n.t("whatsapp.archive.menu.results.empty")
    )
  end

  private

    # The projekt names the row because a citizen recognises the projekt, not
    # the phase; the phase and its end date go in the description.
    def rows
      Whatsapp::PublishedResultsQuery.call(projekt: @projekt).map do |projekt_phase|
        {
          id: ::Whatsapp::Archive::MenuActions.id_for(
            scope: :phase, action: :results, record_id: projekt_phase.id
          ),
          title: Whatsapp::ProjektLink.title(projekt_phase.projekt),
          description: row_description(projekt_phase)
        }
      end
    end

    def row_description(projekt_phase)
      return projekt_phase.title if projekt_phase.end_date.blank?

      I18n.t(
        "whatsapp.archive.projekt_row_description",
        phase: projekt_phase.title,
        end_date: I18n.l(projekt_phase.end_date.to_date)
      )
    end
end
