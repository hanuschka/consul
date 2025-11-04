class Api::PointOfInterestCategoriesController < Api::BaseController
  before_action :find_projekt_phase, only: [:create]
  before_action :find_category, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    category = @projekt_phase.projekt_point_of_interest_categories.new(category_params)

    if category.save
      serialized_category = PointOfInterestCategorySerializer.new(category).serialize

      render json: { data: { category: serialized_category } }, status: 201
    else
      render json: { error: { messages: category.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_category = PointOfInterestCategorySerializer.new(@category).serialize

    render json: { data: { category: serialized_category } }
  end

  def update
    check_admin_access!
    if @category.update(category_params)
      serialized_category = PointOfInterestCategorySerializer.new(@category).serialize

      render json: { data: { category: serialized_category } }
    else
      render json: { error: { messages: @category.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @category.destroy
      render json: { message: "Category destroyed" }
    else
      render json: { error: { messages: @category.errors.messages } }, status: 422
    end
  end

  private

  def category_params
    params.require(:projekt_point_of_interest_category).permit(
      :name,
      :color,
      :icon
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::PointOfInterestPhase.find(params[:projekt_phase_id])
  end

  def find_category
    @category = ProjektPointOfInterestCategory.find(params[:id])
  end
end

