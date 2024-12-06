class ContentCard::LatestResourcesComponent < ApplicationComponent
  delegate :current_user, :current_ability, to: :helpers

  def initialize(content_card)
    @content_card = content_card
    @debates_limit = @content_card.settings["debates_limit"].to_i
    @proposals_limit = @content_card.settings["proposals_limit"].to_i
    @investments_limit = @content_card.settings["investments_limit"].to_i
    @deficiency_reports_limit = @content_card.settings["deficiency_reports_limit"].to_i
  end

  def render?
    latest_resources.any?
  end

  private

    def latest_resources
      @latest_resources = (latest_debates + latest_proposals + latest_investment_proposals + latest_deficiency_reports)
        .sort_by(&:created_at).reverse
    end

    def latest_debates
      Debate.with_current_projekt
        .sort_by_created_at.limit(@debates_limit)
    end

    def latest_proposals
      Proposal.published
              .not_archived
              .not_retired
              .with_current_projekt
              .sort_by_created_at
              .limit(@proposals_limit)
    end

    def latest_investment_proposals
      Budget::Investment.joins(:budget).where.not(budgets: { projekt_phase_id: nil })
        .sort_by_created_at.limit(@investments_limit)
    end

    def latest_deficiency_reports
      DeficiencyReport.accessible_by(current_ability)
        .order(created_at: :desc).limit(@deficiency_reports_limit)
    end
end
