# frozen_string_literal: true

class Api::IdeaCategoriesController < Api::BaseController
  include Translatable

  before_action :find_idea_category, only: [:show, :update, :destroy]

  def index
    check_read_access!
    categories = paginate(Idea::Category.includes(:ideas))

    serialized_categories = IdeaCategorySerializer.serialize_collection(categories)

    render json: {
      data: { idea_categories: serialized_categories },
      pagination: pagination_meta(categories)
    }
  end

  def show
    check_read_access!
    serialized_category = IdeaCategorySerializer.new(@idea_category).serialize

    render json: { data: { idea_category: serialized_category } }
  end

  def create
    check_admin_access!
    category = Idea::Category.new(idea_category_params)

    if category.save
      serialized_category = IdeaCategorySerializer.new(category).serialize

      render json: { data: { idea_category: serialized_category } }, status: 201
    else
      render json: { error: { messages: category.errors.full_messages } }, status: 422
    end
  end

  def update
    check_admin_access!
    @idea_category.assign_attributes(idea_category_params)

    if @idea_category.save
      serialized_category = IdeaCategorySerializer.new(@idea_category).serialize

      render json: { data: { idea_category: serialized_category } }
    else
      render json: { error: { messages: @idea_category.errors.full_messages } }, status: 422
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
      :idea_officer_id
    )
  end

  def find_idea_category
    @idea_category = Idea::Category.find(params[:id])
  end
end
