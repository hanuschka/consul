module Adm::Officing::ProposalPhaseScoped
  extend ActiveSupport::Concern

  private

    def load_proposal_phase
      @proposal_phase = ProjektPhase::ProposalPhase.find(params[:proposal_phase_id] || params[:id])
    end

    def verify_assignment
      unless @proposal_phase.in?(@officing_manager.officing_proposal_phases)
        raise ActionController::RoutingError, "Not Found"
      end
    end

    def officing_desk_path(offline_user)
      officing_desk_adm_officing_proposal_phase_path(@proposal_phase, offline_user_id: offline_user.id)
    end
end
