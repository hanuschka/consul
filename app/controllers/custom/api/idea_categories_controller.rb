# frozen_string_literal: true

class Api::IdeaCategoriesController < Api::BaseController
  include Translatable

  TRANSLATED_ATTRIBUTES = %w[name].freeze

  before_action :find_idea_category, only: [:show, :update, :destroy]

  def index
    check_read_access!
    categories = paginate(Idea::Category.includes(:translations, default_idea_officer: :user))

    serialized_categories = IdeaCategorySerializer.serialize_collection(categories, client: current_client)

    render json: {
      data: { idea_categories: serialized_categories },
      pagination: pagination_meta(categories)
    }
  end

  def show
    check_read_access!
    serialized_category = IdeaCategorySerializer.new(@idea_category, client: current_client).serialize

    render json: { data: { idea_category: serialized_category } }
  end

  def create
    check_admin_access!
    category = Idea::Category.new(idea_category_params)
    translations = assign_requested_translations(category, :idea_category, TRANSLATED_ATTRIBUTES)

    if save_with_translations(category, translations)
      serialized_category = IdeaCategorySerializer.new(category, client: current_client).serialize

      render json: { data: { idea_category: serialized_category } }, status: 201
    else
      render_translated_record_errors(category)
    end
  end

  def update
    check_admin_access!
    @idea_category.assign_attributes(idea_category_params)
    translations = assign_requested_translations(@idea_category, :idea_category, TRANSLATED_ATTRIBUTES)

    if save_with_translations(@idea_category, translations)
      serialized_category = IdeaCategorySerializer.new(@idea_category, client: current_client).serialize

      render json: { data: { idea_category: serialized_category } }
    else
      render_translated_record_errors(@idea_category)
    end
  end

  def destroy
    check_admin_access!

    if @idea_category.safe_to_destroy?
      @idea_category.destroy
      render json: { data: { message: 'Idea category deleted successfully' } }, status: 204
    else
      render json: {
        error: { messages: ['Category cannot be deleted because it has associated ideas'] }
      }, status: 422
    end
  end

  private

  def idea_category_params
    params.require(:idea_category).permit(
      :name,
      :idea_officer_id,
      :color,
      :icon,
      :given_order
    )
  end

  def find_idea_category
    @idea_category = Idea::Category.find(params[:id])
  end
end
