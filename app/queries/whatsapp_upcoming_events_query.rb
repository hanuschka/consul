class WhatsappUpcomingEventsQuery < ApplicationQuery
  MAX_CHOICES = 10

  # Portal-wide, or the events of one projekt. Past events are dropped rather
  # than shown greyed out: a chat row offers no way to say "this already
  # happened" that a citizen would read before tapping it.
  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    scope = ProjektEvent
      .where("projekt_events.datetime >= ?", Time.current)
      .joins(projekt_phase: { projekt: :page })
      .where(site_customization_pages: { status: "published" })
      .merge(Projekt.activated)
      .includes(projekt_phase: { projekt: :page })
      .order(:datetime)
      .limit(MAX_CHOICES)

    scope = scope.where(projekt_phases: { projekt_id: @projekt.id }) if @projekt.present?

    scope.to_a
  end
end
