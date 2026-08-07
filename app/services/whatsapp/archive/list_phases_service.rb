class Whatsapp::Steps::ListPhasesService < ApplicationService
  def initialize(conversation:, projekt:)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Steps::SendListService.call(
      conversation: @conversation,
      rows: rows,
      body: I18n.t(
        "whatsapp.bot.menu.phases.body", projekt: Whatsapp::ProjektLink.title(@projekt)
      ),
      button_label: I18n.t("whatsapp.bot.menu.phases.button"),
      empty_body: I18n.t("whatsapp.bot.menu.phases.empty")
    )
  end

  private

    # Each row opens that phase's own menu rather than its page: a phase is a
    # place with several things in it, not a single destination.
    def rows
      Whatsapp::ProjektPhasesQuery.call(projekt: @projekt).map do |projekt_phase|
        {
          id: Whatsapp::MenuActions.id_for(
            scope: :phase, action: :menu, record_id: projekt_phase.id
          ),
          title: projekt_phase.title,
          description: description_for(projekt_phase)
        }
      end
    end

    def description_for(projekt_phase)
      return I18n.t("whatsapp.bot.menu.phases.closed") if !projekt_phase.current?
      return if projekt_phase.end_date.blank?

      I18n.t("whatsapp.bot.phase_row_description", end_date: I18n.l(projekt_phase.end_date.to_date))
    end
end
