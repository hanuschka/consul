class WhatsappEligiblePhasesQuery < ApplicationQuery
  MAX_CHOICES = 10

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
      scope = ProjektPhase::ProposalPhase.includes(:settings, projekt: :page)
      scope = scope.where(projekt_id: @projekt.id) if @projekt.present?

      scope.to_a
    end

    def eligible?(phase)
      phase.current? &&
        phase.feature?("resource.users_can_create_proposals") &&
        phase.feature?("resource.create_proposal_with_ai")
    end
end
