class WhatsappPhaseContributionsQuery < ApplicationQuery
  MAX_CHOICES = 10

  # Every phase type declares what it holds through resources_name, but only
  # proposal and debate phases expose a `resources` association — the rest reach
  # their content by their own route. So the route is an explicit map keyed by
  # class: no send, no constantize, and a type that is missing simply has
  # nothing to show rather than raising.
  #
  # The six mapped types cover the large majority of live phases; the others are
  # reachable through their page instead.
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    rows = case @projekt_phase
           when ProjektPhase::ProposalPhase then proposals
           when ProjektPhase::BudgetPhase then investments
           when ProjektPhase::VotingPhase then polls
           when ProjektPhase::EventPhase then events
           when ProjektPhase::MilestonePhase then milestones
           when ProjektPhase::ProjektNotificationPhase then notifications
           else []
           end

    rows.first(MAX_CHOICES)
  end

  private

    def proposals
      Proposal
        .where(projekt_phase_id: @projekt_phase.id)
        .order(created_at: :desc)
        .limit(MAX_CHOICES)
        .map { |proposal| row(proposal.title, Whatsapp::PublishedResourceUrl.call(proposal)) }
    end

    def investments
      budget = @projekt_phase.budget

      return [] if budget.blank?

      Budget::Investment
        .where(budget_id: budget.id)
        .includes(:budget)
        .order(created_at: :desc)
        .limit(MAX_CHOICES)
        .map { |investment| row(investment.title, Whatsapp::PublishedResourceUrl.call(investment)) }
    end

    def polls
      Poll
        .where(projekt_phase_id: @projekt_phase.id)
        .order(:ends_at)
        .limit(MAX_CHOICES)
        .map { |poll| row(poll.name, poll_url(poll)) }
    end

    def events
      ProjektEvent
        .where(projekt_phase_id: @projekt_phase.id)
        .where("projekt_events.datetime >= ?", Time.current)
        .order(:datetime)
        .limit(MAX_CHOICES)
        .map { |event| row(event.title, event_url(event), I18n.l(event.datetime.to_date)) }
    end

    def milestones
      Milestone
        .where(milestoneable_type: "ProjektPhase", milestoneable_id: @projekt_phase.id)
        .where.not(publication_date: nil)
        .where("milestones.publication_date <= ?", Time.zone.today)
        .includes(:translations)
        .order(publication_date: :desc)
        .limit(MAX_CHOICES)
        .map { |milestone| milestone_row(milestone) }
    end

    def notifications
      ProjektNotification
        .where(projekt_phase_id: @projekt_phase.id)
        .order(created_at: :desc)
        .limit(MAX_CHOICES)
        .map { |notification| row(notification.title, phase_url) }
    end

    def milestone_row(milestone)
      row(
        milestone.title.presence || I18n.l(milestone.publication_date.to_date),
        phase_url,
        I18n.l(milestone.publication_date.to_date)
      )
    end

    def row(title, url, description = nil)
      { title: title.to_s, url: url, description: description }.compact
    end

    def poll_url(poll)
      Rails.application.routes.url_helpers.poll_url(poll, **UrlOptions.default.to_h)
    end

    # An event's own weblink points outside the portal when the organiser set
    # one; otherwise the phase page is where it is described.
    def event_url(event)
      event.weblink.presence || phase_url
    end

    def phase_url
      @phase_url ||= Whatsapp::ProjektLink.phase_url(@projekt_phase)
    end
end
