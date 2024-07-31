class ContentCard::LatestResourcesComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(settings:)
    @debates_limit = settings["debates_limit"]
    @proposals_limit = settings["proposals_limit"]
    @investments_limit = settings["investments_limit"]
  end

  def render?
    latest_resources.any?
  end

  private

    def latest_resources
      @latest_resources = (latest_debates + latest_proposals + latest_investment_proposals)
        .sort_by(&:created_at).reverse
    end

    def latest_debates
      Debate.with_current_projekt
        .sort_by_created_at.limit(@debates_limit)
    end

    def latest_proposals
      Proposal.published.not_archived.with_current_projekt
        .sort_by_created_at.limit(@proposals_limit)
    end

    def latest_investment_proposals
      Budget::Investment.joins(:budget).where.not(budgets: { projekt_id: nil })
        .sort_by_created_at.limit(@investments_limit)
    end
end
