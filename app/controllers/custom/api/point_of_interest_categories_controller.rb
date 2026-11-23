class Api::PointOfInterestCategoriesController < Api::BaseController
  PRELOADS = [
    { icon_image_attachment: :blob },
    { projekt_phase: [:translations, { projekt: { page: :translations } }] }
  ].freeze

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_category, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      check_phase_visible!(@projekt_phase)
    end

    categories =
      if @projekt_phase.present?
        @projekt_phase.projekt_point_of_interest_categories.includes(PRELOADS)
      elsif current_client.public_data?
        restrict_to_public_phases(ProjektPointOfInterestCategory.includes(PRELOADS))
      else
        ProjektPointOfInterestCategory.includes(PRELOADS)
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
    check_phase_visible!(@category.projekt_phase)

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
      :icon,
      :position
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::PointOfInterestPhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?
  end

  def find_category
    @category = ProjektPointOfInterestCategory.includes(PRELOADS).find(params[:id])
  end
end

