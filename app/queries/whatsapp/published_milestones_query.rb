class Whatsapp::PublishedMilestonesQuery < ApplicationQuery
  # Milestones hang off phases (134 of them) far more than off proposals (2), so
  # progress is read through the phase and reported under its projekt.
  #
  # A milestone dated in the future is a plan, not progress, and the projekt
  # page shows it as such. A chat row cannot, so only past ones are offered.
  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    scope.includes(:translations).limit(::Whatsapp::MAX_LIST_ROWS).to_a
  end

  def exists?
    scope.exists?
  end

  private

    def scope
      Milestone
        .where(milestoneable_type: "ProjektPhase")
        .where(milestoneable_id: phase_ids)
        .where.not(publication_date: nil)
        .where("milestones.publication_date <= ?", Time.zone.today)
        .order(publication_date: :desc)
    end

    def phase_ids
      scope = ProjektPhase.of_publicly_visible_projekt

      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.select(:id)
    end
end
