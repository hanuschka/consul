class Adm::Officing::ProposalVotesController < Adm::Officing::BaseController
  include Adm::Officing::ProposalPhaseScoped

  before_action :load_proposal_phase
  before_action :verify_assignment
  before_action :load_offline_user
  before_action :load_proposal

  def create
    authorize :base, policy_class: Adm::Officing::BasePolicy

    vote_value = %w[yes no].include?(params[:value]) ? params[:value] : "yes"
    @proposal.vote_by(voter: @offline_user, vote: vote_value)

    redirect_to officing_desk_adm_officing_proposal_phase_path(@proposal_phase, offline_user_id: @offline_user.id)
  end

  def destroy
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @proposal.unvote_by(@offline_user)

    redirect_to officing_desk_adm_officing_proposal_phase_path(@proposal_phase, offline_user_id: @offline_user.id)
  end

  private

    def load_proposal
      @proposal = @proposal_phase.proposals.find(params[:proposal_id] || params[:id])
    end
end
