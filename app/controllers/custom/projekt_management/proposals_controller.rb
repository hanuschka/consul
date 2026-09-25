class ProjektManagement::ProposalsController < ProjektManagement::BaseController
  include ModerateActions
  include FeatureFlags

  has_filters %w[all unseen seen], only: :index
  has_orders %w[flags created_at], only: :index

  feature_flag :proposals

  before_action :load_resources, only: [:index, :moderate]

  load_and_authorize_resource

  def index
    super

    respond_to do |format|
      format.html do
        render "moderation/proposals/index"
      end

      format.csv do
        send_data CsvServices::ProposalsExporter.call(@resources.limit(nil)),
          filename: "proposals-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
      end
    end
  end

  def show
    @proposal = Proposal.find(params[:id])
    @projekt_phase = @proposal.projekt_phase
    @similar_contributions = SimilarContributions::FindForProjekt.call(@proposal)

    render "custom/admin/proposals/show"
  end

  def update
    @projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    @proposal = Proposal.find(params[:id])

    if @proposal.update(proposal_params)
      if @projekt_phase.present?
        redirect_to proposals_projekt_management_projekt_phase_path(@projekt_phase), notice: t("admin.proposals.update.notice")
      end
    else
      render :show
    end
  end

  def toggle_image_concealed
    @projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    @proposal = Proposal.find(params[:id])
    @proposal.image.toggle!(:concealed)

    respond_to do |format|
      format.js { render "custom/admin/proposals/toggle_image_concealed" }
    end
  end

  def toggle_admin_accepted
    projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    proposal = projekt_phase.proposals.find(params[:id])

    enabled = ["1", "true"].include?(params[:proposal][:admin_accepted])
    proposal.update!(admin_accepted: enabled)

    head :ok
  end

  private

    def resource_model
      Proposal
    end

    def proposal_params
      params.require(:proposal).permit(:selected, :tag_list, :projekt_id, :related_sdg_list, :official_answer)
    end
end
