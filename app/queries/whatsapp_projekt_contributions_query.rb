class WhatsappProjektContributionsQuery < ApplicationQuery
  # What citizens submitted to this projekt, across all of its proposal and
  # budget phases at once — the projekt-level view of what the phase-level
  # query returns per phase.
  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    rows = proposals_scope.map { |proposal| row(proposal) } +
           investments_scope.includes(:budget).map { |investment| row(investment) }

    rows.sort_by { |contribution| contribution[:created_at] }.reverse.first(::Whatsapp::MAX_LIST_ROWS)
  end

  def exists?
    proposals_scope.exists? || investments_scope.exists?
  end

  private

    # base_selection is the portal's own definition of a publicly listed
    # proposal; see WhatsappPhaseContributionsQuery for why omitting it leaks
    # proposals still awaiting moderation.
    def proposals_scope
      Proposal
        .base_selection
        .where(projekt_phase_id: @projekt.projekt_phases.select(:id))
        .order(created_at: :desc)
        .limit(::Whatsapp::MAX_LIST_ROWS)
    end

    def investments_scope
      budget_ids = Budget.where(projekt_phase_id: @projekt.projekt_phases.select(:id)).select(:id)

      Budget::Investment
        .not_unfeasible
        .where(budget_id: budget_ids)
        .order(created_at: :desc)
        .limit(::Whatsapp::MAX_LIST_ROWS)
    end

    def row(resource)
      {
        title: resource.title.to_s,
        url: Whatsapp::PublishedResourceUrl.call(resource),
        description: I18n.l(resource.created_at.to_date),
        created_at: resource.created_at
      }
    end
end
