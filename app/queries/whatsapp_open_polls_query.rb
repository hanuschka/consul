class WhatsappOpenPollsQuery < ApplicationQuery
  MAX_CHOICES = 10

  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    scope = Poll
      .current
      .joins(projekt_phase: { projekt: :page })
      .where(site_customization_pages: { status: "published" })
      .merge(Projekt.activated)
      .includes(projekt_phase: { projekt: :page })
      .order(:ends_at)
      .limit(MAX_CHOICES)

    scope = scope.where(projekt_phases: { projekt_id: @projekt.id }) if @projekt.present?

    scope.to_a
  end
end
