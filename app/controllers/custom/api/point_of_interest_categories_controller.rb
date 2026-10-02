class Api::PointOfInterestCategoriesController < Api::BaseController
  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_category, only: [:show, :update, :destroy]

  def index
    check_read_access!
    categories = if @projekt_phase.present?
      @projekt_phase.projekt_point_of_interest_categories
        .includes(:projekt_phase, projekt_phase: :projekt)
    else
      ProjektPointOfInterestCategory.includes(:projekt_phase, projekt_phase: :projekt)
    end

    categories = paginate(categories)

    serialized_categories = PointOfInterestCategorySerializer.serialize_collection(categories)

    render json: {
      data: { categories: serialized_categories },
      pagination: pagination_meta(categories)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
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
    @projekt_phase = ProjektPhase::PointOfInterestPhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?
  end

  def find_category
    @category = ProjektPointOfInterestCategory.includes(:projekt_phase, projekt_phase: :projekt).find(params[:id])
  end
end

