class Whatsapp::ProjektPhasesQuery < ApplicationQuery
  # The phases of one projekt that a citizen may look at, whether or not the bot
  # can submit to them: browsing a projekt is not the same as contributing, and
  # a phase the bot cannot take part in still has content worth reading.
  #
  # Capped at what a list holds, and the running phases are put first so the cap can
  # only ever cost a phase that is over or not yet begun. It used to cut in the
  # projekt's own page order alone, which on a projekt that had accumulated many
  # phases loaded the ended ones at the top of that order and never reached the
  # votes running at its end — they were missing from the card's rows and from the
  # summary alike, with nothing saying so. Within each half the page order still holds.
  #
  # The window here has to be the one ProjektPhase.current draws: a debate phase is
  # never current whatever its dates, so ranking it as running would let it outrank a
  # vote that is.
  RUNNING_SQL = <<~SQL.squish
    projekt_phases.type <> 'ProjektPhase::DebatePhase'
      AND (projekt_phases.start_date IS NULL OR projekt_phases.start_date <= :today)
      AND (projekt_phases.end_date IS NULL OR projekt_phases.end_date >= :today)
  SQL

  RUNNING_FIRST_SQL = "CASE WHEN #{RUNNING_SQL} THEN 0 ELSE 1 END".freeze

  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    scope.limit(::Whatsapp::MAX_OFFERED_LIST_ROWS).to_a
  end

  # Every phase, for the projekt card. It orders its rows by what the citizen
  # still has to do and offers the votes it has no room for behind "more",
  # and neither works over a set that stops at ten: a projekt running a
  # proposal phase and ten votes never showed the last of them anywhere.
  def uncapped
    scope.to_a
  end

  # How many of the phases are running, counted past the cap: #call puts them
  # first, so it only ever leaves one out when more than a list holds are
  # running at once, and then nothing it returns says so.
  def running_count
    scope.reorder(nil).where(RUNNING_SQL, today: Time.zone.today).count
  end

  def exists?
    scope.exists?
  end

  private

    # Translations because every caller names the phase, and ProjektPhase#title
    # reads the translated phase_tab_name; settings and the projekt's page
    # because describe_projekt asks each row whether it is open for a
    # submission, which is Whatsapp::EligiblePhasesQuery reading both.
    #
    # `reorder` rather than `order`: ProjektPhase carries a default_scope ordering by
    # given_order, and an appended clause would sort behind it and change nothing.
    def scope
      @projekt
        .projekt_phases
        .where(hidden_at: nil, active: true)
        .includes(:translations, :settings, projekt: :page)
        .reorder(Arel.sql(running_first_order), :given_order, :id)
    end

    def running_first_order
      ProjektPhase.sanitize_sql_array([RUNNING_FIRST_SQL, today: Time.zone.today])
    end
end
