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
    def scope
      relation = Poll
        .joins(projekt_phase: { projekt: :page })
        .merge(ProjektPhase.current)
        .where(site_customization_pages: { status: "published" })
        .merge(Projekt.activated)
        .reorder(:ends_at)

      return relation if @projekt.blank?

      relation.where(projekt_phases: { projekt_id: @projekt.id })
    end
end
