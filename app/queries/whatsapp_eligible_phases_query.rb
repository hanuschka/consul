class WhatsappEligiblePhasesQuery < ApplicationQuery
  # A display cap, not an eligibility rule: #call is what fills a ten-row
  # WhatsApp list. Whether one particular phase may be submitted to is
  # .eligible?, which is uncapped — otherwise the eleventh open phase would be
  # offered in a menu and then refused when tapped.
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

  # The single-phase question, asked without loading the portal. A phase whose
  # projekt is deactivated or whose page is unpublished is not reachable on the
  # website either, so the bot must not take a submission into it.
  def self.eligible?(projekt_phase)
    return false if projekt_phase.blank?
    return false if !projekt_phase.current?
    return false if !projekt_visible?(projekt_phase.projekt)

    feature_keys = feature_keys_for(projekt_phase)

    return false if feature_keys.blank?
    return false if !feature_keys.each_value.all? { |key| projekt_phase.feature?(key) }

    # An investment is built from the budget's heading, so a budget phase
    # without one set up cannot take a submission yet.
    return projekt_phase.budget&.heading.present? if projekt_phase.is_a?(ProjektPhase::BudgetPhase)

    true
  end

  def self.projekt_visible?(projekt)
    return false if projekt.blank?
    return false if projekt.page&.status != "published"

    Projekt.activated.exists?(projekt.id)
  end
  private_class_method :projekt_visible?

  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    base_scope
      .select { |projekt_phase| self.class.eligible?(projekt_phase) }
      .first(MAX_CHOICES)
  end

  private

    def base_scope
      FEATURE_KEYS_BY_PHASE_CLASS.keys.flat_map { |phase_class| phases_of(phase_class) }
    end

    # The date and flag half of ProjektPhase#current?, plus the projekt's own
    # visibility, are plain columns, so they are asked of the database rather
    # than of every phase the portal has ever had. eligible? still re-checks in
    # Ruby: this only decides what is worth loading, never what is eligible.
    def phases_of(phase_class)
      scope =
        phase_class
          .where(hidden_at: nil, active: true)
          .where("projekt_phases.start_date IS NULL OR projekt_phases.start_date <= :today",
                 today: Time.zone.today)
          .where("projekt_phases.end_date IS NULL OR projekt_phases.end_date >= :today",
                 today: Time.zone.today)
          .joins(projekt: :page)
          .where(site_customization_pages: { status: "published" })
          .where(projekt_id: Projekt.activated.select(:id))
          .includes(:settings, projekt: :page)

      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.to_a
    end
end
