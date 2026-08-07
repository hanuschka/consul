class WhatsappProjektContributionsQuery < ApplicationQuery
  MAX_CHOICES = 10

  # What citizens submitted to this projekt, across all of its proposal and
  # budget phases at once — the projekt-level view of what the phase-level
  # query returns per phase.
  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    (proposals + investments).sort_by { |row| row[:created_at] }.reverse.first(MAX_CHOICES)
  end

  private

    def proposals
      Proposal
        .where(projekt_phase_id: @projekt.projekt_phases.select(:id))
        .order(created_at: :desc)
        .limit(MAX_CHOICES)
        .map { |proposal| row(proposal, Whatsapp::PublishedResourceUrl.call(proposal)) }
    end

    def investments
      budget_ids = Budget.where(projekt_phase_id: @projekt.projekt_phases.select(:id)).select(:id)

      Budget::Investment
        .where(budget_id: budget_ids)
        .includes(:budget)
        .order(created_at: :desc)
        .limit(MAX_CHOICES)
        .map { |investment| row(investment, Whatsapp::PublishedResourceUrl.call(investment)) }
    end

    def row(resource, url)
      {
        title: resource.title.to_s,
        url: url,
        description: I18n.l(resource.created_at.to_date),
        created_at: resource.created_at
      }
    end
end
