class Whatsapp::OpenPollsQuery < ApplicationQuery
  def initialize(projekt: nil, from: 0)
    @projekt = projekt
    @from = from
  end

  def call
    scope
      .includes(projekt_phase: { projekt: :page })
      .offset(::Whatsapp::ListWindow.offset(@from))
      .limit(::Whatsapp::ListWindow::ROWS)
      .to_a
  end

  # Every open poll at once, for the counts that have to cover the whole list
  # rather than the page of it on screen.
  def all
    scope.includes(projekt_phase: { projekt: :page }).to_a
  end

  def total
    scope.count
  end

  def exists?
    scope.exists?
  end

  private

    # Open is what ProjektPhase.current says, not Poll.current: that scope compares
    # both phase dates with no regard for nulls and skips active and hidden_at, so
    # an open-ended vote — a phase with no end date, or none of either — was missing
    # from this list and its count while the projekt card, which reads a null date
    # as "no bound" through ProjektPhase#current?, kept offering it as a row. The
    # same citizen was told four votes were running under a card that showed nine.
    #
    # The predicate also asks for hidden_at; the join already carries that, because
    # ProjektPhase's default scope puts it on the association. `reorder` because the
    # same default scope orders by given_order and a merge brings that along, which
    # across projekts sorts by nothing a citizen can read.
    #
    # Published polls only: an unpublished one has no ballot and no address, so
    # listing it counted a vote the citizen still owed that they could not reach.
    def scope
      relation = Poll
        .joins(projekt_phase: { projekt: :page })
        .merge(ProjektPhase.current)
        .where(site_customization_pages: { status: "published" })
        .merge(Projekt.activated)
        .merge(Poll.published)
        .reorder(:ends_at)

      relation.where(projekt_phases: { projekt_id: projekt_ids })
    end

    # Across the whole portal, only the projekts the bot lists as running. A vote
    # in a projekt the overview hides was listed under "eight projekts are
    # running" without its projekt among them, and the buttons after a finished
    # ballot led into it. A projekt the citizen named is taken as named.
    def projekt_ids
      return @projekt.id if @projekt.present?

      ::Whatsapp::BrowsableProjektsQuery.projekt_ids
    end
end
