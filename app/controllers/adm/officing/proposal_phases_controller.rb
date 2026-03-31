class Adm::Officing::ProposalPhasesController < Adm::Officing::BaseController
  include Adm::Officing::ProposalPhaseScoped

  before_action :load_proposal_phase
  before_action :verify_assignment

  def officing_desk
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @offline_user = User.find(params[:offline_user_id])

    @permission_problem = @proposal_phase.permission_problem(@offline_user)

    if @permission_problem.present?
      render "adm/officing/shared/permission_problem" and return
    end

    proposals = @proposal_phase.proposals
                               .includes(:translations)
                               .for_public_render
                               .order(created_at: :desc)

    @pagy, @proposals = pagy(proposals, items: 50)

    @votes_by_proposal_id = ActsAsVotable::Vote
      .where(voter: @offline_user, votable_type: "Proposal", votable_id: @proposals.map(&:id))
      .index_by(&:votable_id)
  end

  def bulk_votes
    authorize :base, policy_class: Adm::Officing::BasePolicy

    proposals = @proposal_phase.proposals
                               .select(:id, :officing_bulk_votes, :projekt_phase_id, :draft, :retired_at, :published_at, :created_at, :hidden_at)
                               .includes(:translations)
                               .for_public_render
                               .order(created_at: :desc)

    @pagy, @proposals = pagy(proposals, items: 50)
  end

  def update_bulk_votes
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @proposal = @proposal_phase.proposals.find(params[:proposal_id])
    @proposal.update_column(:officing_bulk_votes, [0, params[:officing_bulk_votes].to_i].max)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bulk_votes_adm_officing_proposal_phase_path(@proposal_phase) }
    end
  end
end
