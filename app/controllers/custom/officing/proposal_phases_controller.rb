class Officing::ProposalPhasesController < Officing::BaseController
  include OfficingActions

  before_action :set_shared_variables, only: [:officing_desk, :bulk_votes, :update_bulk_votes]

  def officing_desk; end

  def bulk_votes; end

  def update_bulk_votes
    @proposals.each do |proposal|
      proposal.update(officing_bulk_votes: params[:proposals][proposal.id.to_s][:officing_bulk_votes])
    end

    redirect_to action: :bulk_votes
  end

  private

    def set_shared_variables
      @projekt_phase = ProjektPhase.find(params[:id])
      @proposals = @projekt_phase.proposals
                                 .includes([:image, :projekt_labels, :translations, author: [:image, :organization], sentiment: [:translations]])
                                 .for_public_render
                                 .order("created_at DESC")
    end
end
