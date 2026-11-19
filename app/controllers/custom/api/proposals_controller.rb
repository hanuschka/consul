require 'tempfile'

class Api::ProposalsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  TRANSLATED_ATTRIBUTES = ProposalSerializer::TRANSLATED_ATTRIBUTES

  SERIALIZER_PRELOADS = [
    :tags, :geozone, :translations, :masterportal_pin, :map_location,
    { projekt_labels: :translations },
    { sentiment: :translations },
    { author: :organization },
    { image: { attachment_attachment: :blob } },
    { documents: { attachment_attachment: :blob } },
    { projekt_phase: [:settings, { projekt: :page }] }
  ].freeze

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_proposal, only: [:show, :update, :destroy, :publish]

  def index
    check_read_access!

    if @projekt_phase.present? && phase_hidden_from_client?(@projekt_phase)
      raise ForbiddenError, "Access denied"
    end

    proposals =
      if @projekt_phase.present?
        @projekt_phase.resources
      else
        Proposal.all
      end

    if current_client.public_data?
      proposals = restrict_to_public_phases(proposals.discard_draft.discard_archived.admin_accepted)
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

    proposals = paginate(proposals.includes(*SERIALIZER_PRELOADS))

    serialized_proposals = ProposalSerializer.serialize_collection(proposals, client: current_client)

    render json: {
      data: { proposals: serialized_proposals },
      pagination: pagination_meta(proposals)
    }
  end

  def show
    check_read_access!

    if current_client.public_data? && hidden_from_public?(@proposal)
      return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
    end

    serialized_proposal = ProposalSerializer.new(@proposal, client: current_client).serialize

    render json: { data: { proposal: serialized_proposal } }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    proposal = @projekt_phase.resources.new(proposal_create_params.except("image_attributes"))
    proposal.author = @current_client.content_author
    proposal.resource_terms = true
    assign_document_authors(proposal)
    assign_retirement(proposal)
    translations = assign_requested_translations(proposal, :proposal, TRANSLATED_ATTRIBUTES)

    if save_with_translations(proposal, translations)
      process_image_with_base64(proposal, params[:proposal][:image_attributes])

      if publish_on_create?
        proposal.publish
      end

      serialized_proposal = ProposalSerializer.new(proposal, client: current_client).serialize

      render json: { data: { proposal: serialized_proposal } }, status: 201
    else
      render_translated_record_errors(proposal)
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update
    check_admin_access!
    @proposal.assign_attributes(
      with_existing_map_location_id(@proposal, proposal_params.except("image_attributes"))
    )
    assign_document_authors(@proposal)
    assign_retirement(@proposal)
    translations = assign_requested_translations(@proposal, :proposal, TRANSLATED_ATTRIBUTES)

    if save_with_translations(@proposal, translations)
      process_image_with_base64(@proposal, params[:proposal][:image_attributes])

      if @proposal.draft? && publish_on_update?
        @proposal.publish
      end

      serialized_proposal = ProposalSerializer.new(@proposal, client: current_client).serialize

      render json: { data: { proposal: serialized_proposal } }
    else
      render_translated_record_errors(@proposal)
    end
  rescue *SELF_RENDERED_ERRORS
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

    serialized_proposal = ProposalSerializer.new(@proposal, client: current_client).serialize

    render json: { data: { proposal: serialized_proposal } }
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  private

  def proposal_params
    with_decoded_documents(
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
        :summary,
        :retired_reason,
        :retired_explanation,
        projekt_label_ids: [],
        map_location_attributes: map_location_attributes_api,
        documents_attributes: document_attributes_api
      )
    )
  end

  def proposal_create_params
    proposal_params.merge(params.require(:proposal).permit(:external_source, :external_id))
  end

  def assign_retirement(proposal)
    retired = ActiveModel::Type::Boolean.new.cast(params.dig(:proposal, :retired))

    if retired && proposal.retired_at.blank?
      proposal.retired_at = Time.current
    end
  end

  def hidden_from_public?(proposal)
    proposal.draft? ||
      proposal.archived? ||
      !proposal.admin_accepted? ||
      phase_hidden_from_client?(proposal.projekt_phase)
  end

  def publish_on_update?
    ActiveModel::Type::Boolean.new.cast(params.dig(:proposal, :published)) == true
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
    @proposal = Proposal.includes(*SERIALIZER_PRELOADS).find(params[:id])
  end
end

