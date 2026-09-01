require 'tempfile'

class Api::ProposalsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_proposal, only: [:show, :update, :destroy, :publish]

  def index
    check_read_access!
    proposals =
      if @projekt_phase.present?
        @projekt_phase.resources
      else
        Proposal
      end

    if current_client.public_data?
      proposals = proposals.discard_draft.discard_archived
    end

    if params["for_public_render"] == "true"
      proposals = proposals.for_public_render
    end

    orders = %w[hot_score confidence_score created_at relevance archival_date]
    current_order = orders.include?(params[:sort]) ? params[:sort] : "created_at"

    proposals =
      case current_order
      when "hot_score"
        proposals.order(hot_score: :desc, created_at: :asc)
      when "confidence_score"
        proposals.order(confidence_score: :desc, created_at: :asc)
      when "relevance"
        proposals.order(cached_votes_total: :desc, created_at: :asc)
      when "archival_date"
        proposals.order(archival_date: :desc, created_at: :asc)
      else
        proposals.order(created_at: :asc)
      end

    proposals =
      proposals
        .includes(:author, :tags, :geozone, :projekt_labels, :sentiment,
                  projekt_phase: [:settings, { projekt: :page }])
        .page(params[:page])
        .per(params[:per_page] || DEFAULT_PER_PAGE)

    serialized_proposals = ProposalSerializer.serialize_collection(proposals)

    render json: {
      data: { proposals: serialized_proposals },
      pagination: pagination_meta(proposals)
    }
  end

  def show
    check_read_access!

    if current_client.public_data?
      if @proposal.draft? || @proposal.archived?
        return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
      end
    end

    serialized_proposal = ProposalSerializer.new(@proposal).serialize

    render json: { data: { proposal: serialized_proposal } }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    proposal = @projekt_phase.resources.new(proposal_params.except("image_attributes"))
    proposal.author = @current_client.content_author
    proposal.resource_terms = true

    if proposal.save
      process_image_with_base64(proposal, params[:proposal][:image_attributes])

      if publish_on_create?
        proposal.publish
      end

      serialized_proposal = ProposalSerializer.new(proposal).serialize

      render json: { data: { proposal: serialized_proposal } }, status: 201
    else
      render json: { error: { messages: proposal.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update
    check_admin_access!
    @proposal.assign_attributes(proposal_params.except("image_attributes"))

    if @proposal.save
      process_image_with_base64(@proposal, params[:proposal][:image_attributes])
      serialized_proposal = ProposalSerializer.new(@proposal).serialize

      render json: { data: { proposal: serialized_proposal } }
    else
      render json: { error: { messages: @proposal.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def destroy
    check_admin_access!
    if @proposal.destroy
      render json: { message: "Proposal destroyed" }
    else
      render json: { error: { messages: @proposal.errors.messages } }, status: 422
    end
  end

  def publish
    check_admin_access!

    if @proposal.draft?
      @proposal.publish
    end

    serialized_proposal = ProposalSerializer.new(@proposal).serialize

    render json: { data: { proposal: serialized_proposal } }
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  private

  def proposal_params
    params.require(:proposal).permit(
      :responsible_name,
      :video_url,
      :geozone_id,
      :selected,
      :on_behalf_of,
      :sentiment_id,
      :official_answer,
      :admin_accepted,
      :tag_list,
      :related_sdg_list,
      :resource_terms,
      :title,
      :description,
      projekt_label_ids: [],
      map_location_attributes: map_location_attributes,
      documents_attributes: document_attributes
    )
  end

  def publish_on_create?
    published = params.dig(:proposal, :published)
    return true if published.nil?

    ActiveModel::Type::Boolean.new.cast(published)
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::ProposalPhase.find(params[:projekt_phase_id])
  end

  def find_proposal
    @proposal = Proposal
      .includes(:author, :tags, :geozone, :projekt_labels, :sentiment,
                  projekt_phase: [:settings, { projekt: :page }])
      .find(params[:id])
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end

