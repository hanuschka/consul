class ContentCard::LatestResourcesComponent < ApplicationComponent
  delegate :current_user, :current_ability, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @debates_limit = @content_card.settings["debates_limit"].to_i
    @proposals_limit = @content_card.settings["proposals_limit"].to_i
    @investments_limit = @content_card.settings["investments_limit"].to_i
    @deficiency_reports_limit = @content_card.settings["deficiency_reports_limit"].to_i
    @custom_page = custom_page
  end

  def render?
    latest_resources.any?
  end

  private

    def landing_page_projekt_ids
      @custom_page.landing_projekts.activated.ids
    end

    def latest_resources
      @latest_resources =
        (latest_debates + latest_proposals + latest_investment_proposals + latest_deficiency_reports)
        .sort_by(&:created_at).reverse
    end

    def latest_debates
      scoped_projekt_ids = Debate.scoped_projekt_ids_for_index(current_user)

      if @custom_page&.landing?
        scoped_projekt_ids = scoped_projekt_ids & landing_page_projekt_ids
      end

      Debate.with_current_projekt
        .merge(Projekt.show_in_homepage)
        .by_projekt_id(scoped_projekt_ids)
        .sort_by_created_at.limit(@debates_limit)
    end

    def latest_proposals
      scoped_projekt_ids = Proposal.scoped_projekt_ids_for_index(current_user)

      if @custom_page&.landing?
        scoped_projekt_ids = scoped_projekt_ids & landing_page_projekt_ids
      end

      Proposal
        .published
        .not_archived
        .not_retired
        .with_current_projekt
        .merge(Projekt.show_in_homepage)
        .by_projekt_id(scoped_projekt_ids)
        .sort_by_created_at
        .limit(@proposals_limit)
    end

    def latest_investment_proposals
      investment_proposals =
        Budget::Investment
        .joins(budget: { projekt_phase: :projekt })
        .merge(Projekt.show_in_homepage)
        .where.not(budgets: { projekt_phase_id: nil })

      if @custom_page&.landing?
        investment_proposals =
          investment_proposals
            .joins(budget: :projekt_phase)
            .where(projekt_phases: {
              active: true,
              projekt_id: landing_page_projekt_ids
            })
      end

      investment_proposals.sort_by_created_at.limit(@investments_limit)
    end

    def latest_deficiency_reports
      if @custom_page&.landing?
        return []
      end

      DeficiencyReport
        .accessible_by(current_ability)
        .order(created_at: :desc)
        .limit(@deficiency_reports_limit)
    end
end
