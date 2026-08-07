class Whatsapp::Flows::DiscoveryService < ApplicationService
  # Catalog A1's "Show projects", for a linked citizen. Rows are the phases that
  # will actually accept a submission, not every projekt that exists: the offer
  # is made right after linking, and an offer that leads to "you cannot take
  # part here" would be a worse answer than none.
  #
  # A tap goes straight into the proposal prompt for that phase, which is the
  # only thing the catalog does with a chosen projekt.
  def initialize(conversation:, projekt: nil)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Flows::SendListService.call(
      conversation: @conversation,
      rows: rows,
      body: body,
      button_label: I18n.t("whatsapp.bot.discovery.button"),
      empty_body: I18n.t("whatsapp.bot.discovery.empty")
    )
  end

  private

    # Scoped to one projekt when a QR code pointed at a projekt with several
    # open phases: the citizen already chose the projekt by scanning, and
    # offering them the whole portal again would throw that choice away.
    def body
      return I18n.t("whatsapp.bot.discovery.body") if @projekt.blank?

      I18n.t(
        "whatsapp.bot.discovery.phase_body",
        projekt: Whatsapp::ProjektLink.title(@projekt)
      )
    end

    def rows
      Whatsapp::EligiblePhasesQuery.call(projekt: @projekt).map do |projekt_phase|
        {
          id: Whatsapp::FlowActions.id_for(action: :idea_start, param: projekt_phase.id),
          title: Whatsapp::ProjektLink.title(projekt_phase.projekt),
          description: description_for(projekt_phase)
        }
      end
    end

    def description_for(projekt_phase)
      return projekt_phase.name if projekt_phase.end_date.blank?

      I18n.t(
        "whatsapp.bot.discovery.row_description",
        phase: projekt_phase.name,
        end_date: I18n.l(projekt_phase.end_date)
      )
    end
end
