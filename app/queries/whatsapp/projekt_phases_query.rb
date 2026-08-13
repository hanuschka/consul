class Whatsapp::ProjektPhasesQuery < ApplicationQuery
  # The phases of one projekt that a citizen may look at, whether or not the bot
  # can submit to them: browsing a projekt is not the same as contributing, and
  # a phase the bot cannot take part in still has content worth reading.
  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    scope.limit(::Whatsapp::MAX_LIST_ROWS).to_a
  end

  def exists?
    scope.exists?
  end

  private

    # Translations because every caller names the phase, and ProjektPhase#title
    # reads the translated phase_tab_name; settings and the projekt's page
    # because describe_projekt asks each row whether it is open for a
    # submission, which is Whatsapp::EligiblePhasesQuery reading both.
    def scope
      @projekt
        .projekt_phases
        .where(hidden_at: nil, active: true)
        .includes(:translations, :settings, projekt: :page)
        .order(:given_order, :id)
    end
end
