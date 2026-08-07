class WhatsappProjektPhasesQuery < ApplicationQuery
  MAX_CHOICES = 10

  # The phases of one projekt that a citizen may look at, whether or not the bot
  # can submit to them: browsing a projekt is not the same as contributing, and
  # a phase the bot cannot take part in still has content worth reading.
  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    @projekt
      .projekt_phases
      .where(hidden_at: nil, active: true)
      .order(:given_order, :id)
      .limit(MAX_CHOICES)
      .to_a
  end
end
