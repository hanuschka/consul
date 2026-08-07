class WhatsappPublishedMilestonesQuery < ApplicationQuery
  MAX_CHOICES = 10

  # Milestones hang off phases (134 of them) far more than off proposals (2), so
  # progress is read through the phase and reported under its projekt.
  #
  # A milestone dated in the future is a plan, not progress, and the projekt
  # page shows it as such. A chat row cannot, so only past ones are offered.
  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    Milestone
      .where(milestoneable_type: "ProjektPhase")
      .where(milestoneable_id: phase_ids)
      .where.not(publication_date: nil)
      .where("milestones.publication_date <= ?", Time.zone.today)
      .includes(:translations)
      .order(publication_date: :desc)
      .limit(MAX_CHOICES)
      .to_a
  end

  private

    def phase_ids
      scope = ProjektPhase
        .joins(projekt: :page)
        .where(site_customization_pages: { status: "published" })
        .merge(Projekt.activated)

      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.select(:id)
    end
end
