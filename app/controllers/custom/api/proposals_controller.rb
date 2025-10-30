class Api::ProposalsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_proposal, only: [:show, :update, :destroy]

  def index
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
    serialized_proposal = ProposalSerializer.new(@proposal).serialize

    render json: { data: { proposal: serialized_proposal } }
  end

  def create
    proposal = @projekt_phase.resources.new(proposal_params)
    proposal.author = GuestUser.new

    if proposal.save(context: :api)
      serialized_proposal = ProposalSerializer.new(proposal).serialize

      render json: { data: { proposal: serialized_proposal } }, status: 201
    else
      render json: { error: { messages: proposal.errors.full_messages } }, status: 422
    end
  end

  def update
    if @proposal.update(proposal_params)
      serialized_proposal = ProposalSerializer.new(@proposal).serialize

      render json: { data: { proposal: serialized_proposal } }
    else
      render json: { error: { messages: @proposal.errors.full_messages } }, status: 422
    end
  end

  def destroy
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
      *translation_params(Proposal),
      projekt_label_ids: [],
      map_location_attributes: map_location_attributes,
      image_attributes: image_attributes,
      documents_attributes: document_attributes,
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

