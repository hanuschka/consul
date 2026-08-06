class WhatsappEligiblePhasesQuery < ApplicationQuery
  MAX_CHOICES = 10

  # Both flags have to be on for a phase to be reachable from the bot: the one
  # that lets citizens create the resource at all, and the one that enables the
  # AI flow the bot is a channel for.
  FEATURE_KEYS_BY_PHASE_CLASS = {
    ProjektPhase::ProposalPhase => {
      creation: "resource.users_can_create_proposals",
      ai_flow: "resource.create_proposal_with_ai"
    }.freeze,
    ProjektPhase::BudgetPhase => {
      creation: "resource.users_can_create_investment_proposals",
      ai_flow: "resource.create_investment_with_ai"
    }.freeze
  }.freeze

  def self.feature_keys_for(projekt_phase)
    FEATURE_KEYS_BY_PHASE_CLASS[projekt_phase.class]
  end

  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    base_scope
      .select { |phase| eligible?(phase) }
      .first(MAX_CHOICES)
  end

  private

    def base_scope
      FEATURE_KEYS_BY_PHASE_CLASS.keys.flat_map { |phase_class| phases_of(phase_class) }
    end

    # The date and flag half of ProjektPhase#current? is plain columns, so it is
    # asked of the database rather than of every phase the portal has ever had.
    # eligible? still re-checks in Ruby: this only decides what is worth loading,
    # never what is eligible.
    def phases_of(phase_class)
      scope =
        phase_class
          .where(hidden_at: nil, active: true)
          .where("projekt_phases.start_date IS NULL OR projekt_phases.start_date <= :today",
                 today: Time.zone.today)
          .where("projekt_phases.end_date IS NULL OR projekt_phases.end_date >= :today",
                 today: Time.zone.today)
          .includes(:settings, projekt: :page)

      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.to_a
    end

    def eligible?(phase)
      return false if !phase.current?

      feature_keys = self.class.feature_keys_for(phase)

      return false if feature_keys.blank?
      return false if !feature_keys.each_value.all? { |key| phase.feature?(key) }

      # An investment is built from the budget's heading, so a budget phase
      # without one set up cannot take a submission yet.
      return phase.budget&.heading.present? if phase.is_a?(ProjektPhase::BudgetPhase)

      true
    end
end
