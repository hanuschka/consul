require 'tempfile'

class Api::ProposalsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_proposal, only: [:show, :update, :destroy]

  def index
    check_read_access!
    proposals =
        @projekt_phase.resources
            .includes(:author, :tags, :geozone, :projekt_labels, :sentiment, projekt_phase: { projekt: :page })
            .page(params[:page])
            .per(params[:per_page] || 100)

    if params["for_public_render"] == "true"
      proposals = proposals.for_public_render
    end

    serialized_proposals = ProposalSerializer.serialize_collection(proposals)

    render json: {
      data: { proposals: serialized_proposals },
      pagination: pagination_meta(proposals)
    }
  end

  def show
    check_read_access!
    serialized_proposal = ProposalSerializer.new(@proposal).serialize

    render json: { data: { proposal: serialized_proposal } }
  end

  def create
    check_admin_access!
    proposal = @projekt_phase.resources.new(proposal_params)
    proposal.author = @current_client.user
    proposal.resource_terms = true

    if proposal.save
      if params[:proposal]&.key?(:image_attributes)
        process_image_with_base64(proposal, proposal_params[:image_attributes])
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
    @proposal.assign_attributes(proposal_params)

    if @proposal.save
      process_image_with_base64(@proposal, params[:proposal][:image_attributes]) if params[:proposal]&.key?(:image_attributes)

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
      image_attributes: image_attributes,
      documents_attributes: document_attributes,
      translations_attributes: [:id, :locale, :_destroy, :title, :description, :summary, :retired_explanation]
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::ProposalPhase.find(params[:projekt_phase_id])
  end

  def find_proposal
    @proposal = Proposal
      .includes(:author, :tags, :geozone, :projekt_labels, :sentiment, projekt_phase: { projekt: :page })
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

