class Whatsapp::PhaseContributionsQuery < ApplicationQuery
  # Every phase type declares what it holds through resources_name, but only
  # proposal and debate phases expose a `resources` association — the rest reach
  # their content by their own route. So the route is an explicit map keyed by
  # class: no send, no constantize, and a type that is missing simply has
  # nothing to show rather than raising.
  #
  # The six mapped types cover the large majority of live phases; the others are
  # reachable through their page instead.
  # The same six as the branches below, named so a caller can ask whether this has
  # anything to say about a phase without running the query to find out. The projekt
  # card asks it for every phase of every projekt the bot names, where a count each is
  # a query each — for a button whose page says so itself when there is nothing there.
  # Beside the branches rather than anywhere else, because two lists of the same six
  # in two files is how one of them comes to be missing a type.
  SHOWN_PHASE_CLASSES = [
    ProjektPhase::ProposalPhase, ProjektPhase::BudgetPhase, ProjektPhase::VotingPhase,
    ProjektPhase::EventPhase, ProjektPhase::MilestonePhase,
    ProjektPhase::ProjektNotificationPhase
  ].freeze

  def self.shows_for?(projekt_phase)
    SHOWN_PHASE_CLASSES.include?(projekt_phase.class)
  end

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    return [] if relation.blank?

    relation.limit(::Whatsapp::MAX_OFFERED_LIST_ROWS).map { |record| row_for(record) }.compact
  end

  # Counted rather than measured off the rows, which are capped: the reply says how
  # many of the total it names, and a number read off a capped list would say nine
  # of nine on a phase holding two hundred.
  def total
    return 0 if relation.blank?

    relation.count
  end

  private

    # The scope alone, unlimited and unmapped, because the reply needs both the rows
    # and the number they were taken from — and a branch that mapped as it went could
    # only be counted by running it twice.
    def relation
      return @relation if defined?(@relation)

      @relation = case @projekt_phase
                  when ProjektPhase::ProposalPhase then proposals
                  when ProjektPhase::BudgetPhase then investments
                  when ProjektPhase::VotingPhase then polls
                  when ProjektPhase::EventPhase then events
                  when ProjektPhase::MilestonePhase then milestones
                  when ProjektPhase::ProjektNotificationPhase then notifications
                  end
    end

    # base_selection is the portal's own definition of a publicly listed
    # proposal: published, not archived, not retired, admin-accepted. The bot
    # publishes with admin_accepted false wherever a phase moderates, so without
    # it this digest would hand out links to proposals awaiting moderation.
    def proposals
      Proposal
        .base_selection
        .where(projekt_phase_id: @projekt_phase.id)
        .order(created_at: :desc)
    end

    def investments
      budget = @projekt_phase.budget

      return if budget.blank?

      Budget::Investment
        .not_unfeasible
        .where(budget_id: budget.id)
        .includes(:budget)
        .order(created_at: :desc)
    end

    def polls
      Poll.where(projekt_phase_id: @projekt_phase.id).order(:ends_at)
    end

    def events
      ProjektEvent
        .where(projekt_phase_id: @projekt_phase.id)
        .where("projekt_events.datetime >= ?", Time.current)
        .order(:datetime)
    end

    def milestones
      Milestone
        .where(milestoneable_type: "ProjektPhase", milestoneable_id: @projekt_phase.id)
        .where.not(publication_date: nil)
        .where("milestones.publication_date <= ?", Time.zone.today)
        .includes(:translations)
        .order(publication_date: :desc)
    end

    def notifications
      ProjektNotification.where(projekt_phase_id: @projekt_phase.id).order(created_at: :desc)
    end

    # Dispatched on the record rather than on the phase a second time, so each type
    # names its own title column, its own date and its own way of being opened in one
    # place.
    def row_for(record)
      case record
      when ::Proposal, ::Budget::Investment then contribution_row(record)
      when ::Poll then row(title: record.name, url: poll_url(record), description: relative(record.ends_at))
      when ::ProjektEvent
        row(title: record.title, url: event_url(record), description: absolute(record.datetime))
      when ::Milestone then milestone_row(record)
      when ::ProjektNotification
        row(title: record.title, url: phase_url, description: relative(record.created_at))
      end
    end

    # The only two kinds a row can also be tapped for. Whatsapp::ContributionPill
    # answers nil for anything else, which is what keeps a poll or an event out of the
    # selectable list while it is still named in the message.
    def contribution_row(record)
      row(
        title: record.title,
        url: ::Whatsapp::PublishedResourceUrl.call(record),
        description: relative(record.created_at),
        action_id: ::Whatsapp::ContributionPill.id_for(record)
      )
    end

    def milestone_row(milestone)
      published_on = absolute(milestone.publication_date)

      row(title: milestone.title.presence || published_on, url: phase_url, description: published_on)
    end

    def row(title:, url:, description: nil, action_id: nil)
      { title: title.to_s, url: url, description: description, action_id: action_id }.compact
    end

    def relative(value)
      ::Whatsapp::DatePhrase.relative(value)
    end

    def absolute(value)
      ::Whatsapp::DatePhrase.absolute(value)
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
