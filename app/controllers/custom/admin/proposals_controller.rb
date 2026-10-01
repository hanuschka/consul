class Admin::ProposalsController < Admin::BaseController
  include HasOrders
  include CommentableActions
  include FeatureFlags
  feature_flag :proposals

  has_orders %w[created_at]

  before_action :load_proposal, except: [:index, :comments]
  before_action :set_projekts_for_selector, only: [:update, :show]

  EXPORT_SYNC_RECORD_LIMIT = 5000

  def index
    super

    respond_to do |format|
      format.html
      format.csv do
        send_data CsvServices::ProposalsExporter.call(@resources.limit(nil)),
          filename: "proposals-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
      end
      format.geojson { send_geojson_export }
    end
  end

  def show
    @affiliated_districts = (params[:affiliated_districts] || '').split(',').map(&:to_i)
    @projekt_phase = @proposal.projekt_phase
    @similar_contributions = SimilarContributions::FindForProjekt.call(@proposal)
  end

  def edit
    @projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    @proposal = Proposal.find(params[:id])
  end

  def update
    @projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    @proposal = Proposal.find(params[:id])

    if @proposal.update(proposal_params)
      if @projekt_phase.present?
        redirect_to proposals_admin_projekt_phase_path(@projekt_phase), notice: t("admin.proposals.update.notice")
      else
        redirect_to admin_proposal_path(@proposal), notice: t("admin.proposals.update.notice")
      end
    else
      render :show
    end
  end

  def toggle_selection
    @proposal.toggle :selected
    @proposal.save!
  end

  def toggle_image_concealed
    @projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    @proposal = Proposal.find(params[:id])
    @proposal.image.toggle!(:concealed)

    respond_to do |format|
      format.js { render "custom/admin/proposals/toggle_image_concealed" }
    end
  end

  def comments
    @comments = Comment.not_valuations.where(commentable_type: "Proposal").sort_by_newest

    respond_to do |format|
      format.csv do
        CsvJobs::CommentsJob.perform_later(current_user.id, @comments.ids, "proposals")
        redirect_to admin_proposals_path, notice: "Export wird vorbereitet. Du erhältst eine E-Mail, sobald der Export fertig ist."
      end
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

    def send_geojson_export
      scope = @resources.limit(nil)
      source_filter = params[:source_filter].presence || "all"

      if scope.count > EXPORT_SYNC_RECORD_LIMIT
        redirect_to admin_proposals_path,
                    notice: t("admin.proposals.index.export_queued")
        return
      end

      send_data GeoServices::GeoJsonExporter.call(scope, source_filter: source_filter),
                filename: "proposals-#{Time.current.to_i}.geojson",
                type: "application/geo+json"
    end

    def resource_model
      Proposal
    end

    def load_proposal
      @proposal = Proposal.find(params[:id])
    end

    def load_proposals
      @investments = Budget::Investment.scoped_filter(params, @current_filter).order_filter(params)
      @investments = Kaminari.paginate_array(@investments) if @investments.is_a?(Array)
      @investments = @investments.page(params[:page]) unless request.format.csv?
    end

    def proposal_params
      params.require(:proposal).permit(:selected, :tag_list, :projekt_id, :related_sdg_list, :official_answer)
    end
end
