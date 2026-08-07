class Whatsapp::UpcomingEventsQuery < ApplicationQuery
  # Portal-wide, or the events of one projekt. Past events are dropped rather
  # than shown greyed out: a chat row offers no way to say "this already
  # happened" that a citizen would read before tapping it.
  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    scope.includes(projekt_phase: { projekt: :page }).limit(::Whatsapp::MAX_LIST_ROWS).to_a
  end

  def exists?
    scope.exists?
  end

  private

    def scope
      relation = ProjektEvent
        .where("projekt_events.datetime >= ?", Time.current)
        .joins(projekt_phase: { projekt: :page })
        .where(site_customization_pages: { status: "published" })
        .merge(Projekt.activated)
        .order(:datetime)

      return relation if @projekt.blank?

      relation.where(projekt_phases: { projekt_id: @projekt.id })
    end
end
