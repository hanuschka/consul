class Whatsapp::EligiblePhasesQuery < ApplicationQuery
  # The phase types the bot has a submission flow for. Which flags each of them
  # reads is the phase's own business — #selectable_by_users? and
  # #ai_flow_feature_key — so adding a third type here is the only edit.
  PHASE_CLASSES = [ProjektPhase::ProposalPhase, ProjektPhase::BudgetPhase].freeze

  # The single-phase question, asked without loading the portal. A phase whose
  # projekt is deactivated or whose page is unpublished is not reachable on the
  # website either, so the bot must not take a submission into it.
  #
  # Both flags have to be on: the one that lets citizens create the resource at
  # all, and the one that enables the AI flow the bot is a channel for.
  def self.eligible?(projekt_phase)
    return false if projekt_phase.blank?
    return false if !PHASE_CLASSES.include?(projekt_phase.class)
    return false if !projekt_phase.current?
    return false if !projekt_visible?(projekt_phase.projekt)
    return false if !projekt_phase.selectable_by_users?
    return false if !projekt_phase.ai_flow_enabled?

    # An investment is built from the budget's heading, so a budget phase
    # without one set up cannot take a submission yet.
    return projekt_phase.budget&.heading.present? if projekt_phase.is_a?(ProjektPhase::BudgetPhase)

    true
  end

  # Read off the already-loaded projekt rather than asked of the database: the
  # collection path eager-loads it, and both stores behind Projekt.activated are
  # kept in sync, so the column is current whichever one the scope reads.
  def self.projekt_visible?(projekt)
    return false if projekt.blank?
    return false if projekt.page&.status != "published"

    projekt.activated?
  end
  private_class_method :projekt_visible?

  def initialize(projekt: nil)
    @projekt = projekt
  end

  # A display cap, not an eligibility rule: #call is what fills a ten-row
  # WhatsApp list. Whether one particular phase may be submitted to is
  # .eligible?, which is uncapped — otherwise the eleventh open phase would be
  # offered in a menu and then refused when tapped.
  def call
    candidates
      .select { |projekt_phase| self.class.eligible?(projekt_phase) }
      .first(::Whatsapp::MAX_LIST_ROWS)
  end

  # Stops at the first eligible phase. The menus ask only whether anything is
  # open at all, and answering that by materialising ten phases with their
  # settings and pages is the most expensive question the bot asks.
  def exists?
    candidates.lazy.any? { |projekt_phase| self.class.eligible?(projekt_phase) }
  end

  private

    def candidates
      PHASE_CLASSES.flat_map { |phase_class| phases_of(phase_class) }
    end

    # The date and flag half of ProjektPhase#current?, plus the projekt's own
    # visibility, are plain columns, so they are asked of the database rather
    # than of every phase the portal has ever had. eligible? still re-checks in
    # Ruby: this only decides what is worth loading, never what is eligible.
    def phases_of(phase_class)
      scope =
        phase_class
          .current
          .where(hidden_at: nil)
          .of_publicly_visible_projekt
          .includes(preloads_for(phase_class))

      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.to_a
    end

    # eligible? asks a budget phase for its heading, which is two more queries
    # per phase unless the chain comes along with the rest.
    def preloads_for(phase_class)
      preloads = [:settings, { projekt: :page }]

      return preloads if phase_class != ProjektPhase::BudgetPhase

      preloads + [{ budget: :heading }]
    end
end
