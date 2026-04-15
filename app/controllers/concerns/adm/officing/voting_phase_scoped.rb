module Adm::Officing::VotingPhaseScoped
  extend ActiveSupport::Concern

  private

    def load_voting_phase
      @voting_phase = ProjektPhase::VotingPhase.find(params[:voting_phase_id] || params[:id])
    end

    def verify_assignment
      unless @voting_phase.in?(@officing_manager.officing_voting_phases)
        raise ActionController::RoutingError, "Not Found"
      end
    end

    def officing_desk_path(offline_user)
      officing_desk_adm_officing_voting_phase_path(@voting_phase, offline_user_id: offline_user.id)
    end
end
