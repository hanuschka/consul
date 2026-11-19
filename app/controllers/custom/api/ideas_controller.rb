# frozen_string_literal: true

class Api::IdeasController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  TRANSLATED_ATTRIBUTES = IdeaSerializer::ADMIN_TRANSLATED_ATTRIBUTES

  ACCEPTANCE_FILTERS = %w[accepted pending all].freeze

  SERIALIZER_PRELOADS = [
    :map_location,
    :translations,
    { category: :translations },
    { image: { attachment_attachment: :blob } },
    { documents: { attachment_attachment: :blob } },
    { author: :organization }
  ].freeze

  before_action :find_idea, only: [:show, :update]

  def index
    check_read_access!
    ideas = filter_by_acceptance(Idea.includes(*SERIALIZER_PRELOADS))
    ideas = paginate(apply_sorting(apply_filters(ideas)))

    serialized_ideas = IdeaSerializer.serialize_collection(ideas, client: current_client)

    render json: {
      data: { ideas: serialized_ideas },
      pagination: pagination_meta(ideas)
    }
  end

  def show
    check_read_access!

    if current_client.public_data? && @idea.admin_accepted_at.blank?
      raise ForbiddenError, "Access denied"
    end

    serialized_idea = IdeaSerializer.new(@idea, client: current_client).serialize

    render json: { data: { idea: serialized_idea } }
  end

  def create
    check_admin_access!
    idea = Idea.new(idea_params)
    idea.author = @current_client.content_author
    idea.resource_terms = true
    assign_document_authors(idea)
    assign_acceptance(idea)
    translations = assign_requested_translations(idea, :idea, TRANSLATED_ATTRIBUTES)

    idea.officer = idea.get_default_officer if idea.respond_to?(:get_default_officer)

    if save_with_translations(idea, translations)
      process_image_with_base64(idea, params[:idea][:image_attributes])
      serialized_idea = IdeaSerializer.new(idea, client: current_client).serialize

      render json: { data: { idea: serialized_idea } }, status: 201
    else
      render_translated_record_errors(idea)
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update
    check_admin_access!
    @idea.assign_attributes(with_existing_map_location_id(@idea, idea_params))
    assign_document_authors(@idea)
    assign_acceptance(@idea)
    translations = assign_requested_translations(@idea, :idea, TRANSLATED_ATTRIBUTES)

    if save_with_translations(@idea, translations)
      process_image_with_base64(@idea, params[:idea][:image_attributes])
      serialized_idea = IdeaSerializer.new(@idea, client: current_client).serialize

      render json: { data: { idea: serialized_idea } }
    else
      render_translated_record_errors(@idea)
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  private

  def idea_params
    with_decoded_documents(
      params.require(:idea).permit(
        :title,
        :description,
        :resource_terms,
        :idea_category_id,
        :video_url,
        :on_behalf_of,
        :official_answer,
        :timeframe,
        :votes_needed_for_success,
        map_location_attributes: map_location_attributes_api,
        documents_attributes: document_attributes_api
      )
    )
  end

  # Read-only clients only get the accepted ideas the site lists; admin
  # clients can ask for the pending ones too.
  def filter_by_acceptance(ideas)
    acceptance =
      if admin_client? && ACCEPTANCE_FILTERS.include?(params[:acceptance])
        params[:acceptance]
      else
        "accepted"
      end

    case acceptance
    when "accepted"
      ideas.accepted
    when "pending"
      ideas.where(admin_accepted_at: nil)
    else
      ideas
    end
  end

  # The acceptance date starts the idea's timeframe, so accepting an already
  # accepted idea again keeps the original date.
  def assign_acceptance(idea)
    return if !params[:idea].key?(:accepted)

    accepted = ActiveModel::Type::Boolean.new.cast(params[:idea][:accepted])

    if !accepted
      idea.admin_accepted_at = nil
    elsif idea.admin_accepted_at.blank?
      idea.admin_accepted_at = Time.zone.now
    end
  end

  def find_idea
    @idea = Idea.includes(*SERIALIZER_PRELOADS).find(params[:id])
  end

  def apply_filters(ideas)
    if params[:idea_category].present?
      ideas = ideas.where(idea_category_id: params[:idea_category])
    end

    case params[:status]
    when "active"
      ideas = ideas.filter_by_status_active
    when "archived"
      ideas = ideas.filter_by_status_archived
    end

    case params[:quorum]
    when "reached"
      ideas = ideas.filter_by_quorum_reached
    when "not_reached"
      ideas = ideas.filter_by_quorum_not_reached
    end

    ideas
  end

  # The id tiebreaker keeps rows with equal sort values from moving between
  # pages.
  def apply_sorting(ideas)
    sorted_ideas =
      case params[:order]
      when "most_supported"
        ideas.sort_by_most_supported
      when "most_commented"
        ideas.sort_by_most_commented
      else
        ideas.sort_by_newest
      end

    sorted_ideas.order(id: :desc)
  end
end

