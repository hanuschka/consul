class Whatsapp::Flows::DiscoveryService < Whatsapp::Flows::BaseService
  # Catalog A1's "Show projects", for a linked citizen. Rows are the phases that
  # will actually accept a submission, not every projekt that exists: the offer
  # is made right after linking, and an offer that leads to "you cannot take
  # part here" would be a worse answer than none.
  #
  # A tap goes straight into the proposal prompt for that phase, which is the
  # only thing the catalog does with a chosen projekt.
  # projekt_phases is passed in by a caller that has already resolved them, so
  # the same query does not run twice for one tap.
  def initialize(conversation:, projekt: nil, projekt_phases: nil)
    super(conversation: conversation)
    @projekt = projekt
    @projekt_phases = projekt_phases
  end

  def call
    Whatsapp::Flows::SendListService.call(
      conversation: @conversation,
      rows: rows,
      body: body,
      button_label: I18n.t("whatsapp.bot.discovery.button"),
      empty_body: Whatsapp.phrase("whatsapp.bot.discovery.empty")
    )
  end

  private

    # Scoped to one projekt when a QR code pointed at a projekt with several
    # open phases: the citizen already chose the projekt by scanning, and
    # offering them the whole portal again would throw that choice away.
    def body
      if @projekt.blank?
        return Whatsapp.phrase("whatsapp.bot.discovery.body")
      end

      Whatsapp.phrase("whatsapp.bot.discovery.phase_body", projekt: Whatsapp::ProjektLink.title(@projekt))
    end

    def rows
      Whatsapp::PhaseListRows.build(
        @projekt_phases || Whatsapp::EligiblePhasesQuery.call(projekt: @projekt)
      )
    end
end
