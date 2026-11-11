class Api::Configuration::TagCategoriesController < Api::Configuration::BaseController
  NAME_TAKEN_BY_TAG_MESSAGE = "is already used by a tag that is not a category".freeze

  before_action :find_tag_category, only: [:show, :update, :destroy]

  def index
    tag_categories = paginate(Tag.category.order(:id))

    render json: {
      data: { tag_categories: tag_categories.map { serialize(it) } },
      pagination: pagination_meta(tag_categories)
    }
  end

  def show
    render json: { data: { tag_category: serialize(@tag_category) } }
  end

  # Unlike /adm, an existing tag users added is never turned into a category.
  def create
    tag_category = Tag.new(name: tag_category_params[:name], kind: "category")

    if name_taken_by_tag?(tag_category.name)
      return render_invalid_values("name" => [NAME_TAKEN_BY_TAG_MESSAGE])
    end

    if tag_category.save
      render json: { data: { tag_category: serialize(tag_category) } }, status: :created
    else
      render_record_errors(tag_category)
    end
  end

  def update
    @tag_category.name = tag_category_params[:name]

    if name_taken_by_tag?(@tag_category.name)
      return render_invalid_values("name" => [NAME_TAKEN_BY_TAG_MESSAGE])
    end

    if @tag_category.save
      render json: { data: { tag_category: serialize(@tag_category) } }
    else
      render_record_errors(@tag_category)
    end
  end

  def destroy
    @tag_category.destroy!

    head :no_content
  end

  private

    def find_tag_category
      @tag_category = Tag.category.find(params[:id])
    end

    def tag_category_params
      params.require(:tag_category).permit(:name)
    end

    def name_taken_by_tag?(name)
      Tag.where(name:).where("kind IS DISTINCT FROM ?", "category").exists?
    end

    def serialize(tag_category)
      {
        id: tag_category.id,
        name: tag_category.name,
        taggings_count: tag_category.taggings_count
      }
    end
end
