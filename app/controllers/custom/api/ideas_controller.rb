# frozen_string_literal: true

class Api::IdeasController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  before_action :find_idea, only: [:show, :update]

  def index
    check_read_access!
    ideas = paginate(Idea.accepted.includes(:author, :category, :map_location))

    ideas = apply_filters(ideas)
    ideas = apply_sorting(ideas)

    serialized_ideas = IdeaSerializer.serialize_collection(ideas)

    render json: {
      data: { ideas: serialized_ideas },
      pagination: pagination_meta(ideas)
    }
  end

  def show
    check_read_access!
    serialized_idea = IdeaSerializer.new(@idea).serialize

    render json: { data: { idea: serialized_idea } }
  end

  def create
    check_admin_access!
    idea = Idea.new(idea_params)
    idea.author = @current_client.content_author
    idea.resource_terms = true

    idea.officer = idea.get_default_officer if idea.respond_to?(:get_default_officer)

    if idea.save
      process_image_with_base64(idea, params[:idea][:image_attributes])
      serialized_idea = IdeaSerializer.new(idea).serialize

      render json: { data: { idea: serialized_idea } }, status: 201
    else
      render json: { error: { messages: idea.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update
    check_admin_access!
    @idea.assign_attributes(idea_params)

    if @idea.save
      process_image_with_base64(@idea, params[:idea][:image_attributes])
      serialized_idea = IdeaSerializer.new(@idea).serialize

      render json: { data: { idea: serialized_idea } }
    else
      render json: { error: { messages: @idea.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  private

  def idea_params
    params.require(:idea).permit(
      :title,
      :description,
      :resource_terms,
      :idea_category_id,
      :video_url,
      :on_behalf_of,
      map_location_attributes: map_location_attributes,
      documents_attributes: document_attributes
    )
  end

  def find_idea
    @idea = Idea.find(params[:id])
  end

  def apply_filters(ideas)
    if params[:idea_category].present?
      ideas = ideas.where(idea_category_id: params[:idea_category])
    end

    if params[:status].in? %w[active archived]
      ideas = ideas.send("filter_by_status_#{params[:status]}")
    end

    if params[:quorum].in? %w[reached not_reached]
      ideas = ideas.send("filter_by_quorum_#{params[:quorum]}")
    end

    ideas
  end

  def apply_sorting(ideas)
    order = params[:order] || 'newest'
    if Idea.idea_orders.include?(order)
      ideas = ideas.send("sort_by_#{order}")
    end
    ideas
  end
end

