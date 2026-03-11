class Adm::Ideas::CategoriesController < Adm::Ideas::BaseController
  include Translatable

  def index
    @categories = policy_scope(Idea::Category, policy_scope_class: Adm::Ideas::CategoryPolicy::Scope)
                    .order(:given_order)
  end

  def new
    @category = Idea::Category.new
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy
  end

  def edit
    @category = Idea::Category.find(params[:id])
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy
  end

  def create
    @category = Idea::Category.new(category_params)
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    if @category.save
      redirect_to adm_ideas_categories_path
    else
      render :new
    end
  end

  def update
    @category = Idea::Category.find(params[:id])
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    if @category.update(category_params)
      redirect_to adm_ideas_categories_path
    else
      render :edit
    end
  end

  def destroy
    @category = Idea::Category.find(params[:id])
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    if @category.safe_to_destroy?
      @category.destroy!
      redirect_to adm_ideas_categories_path, notice: t("custom.admin.ideas.categories.destroy.destroyed_successfully")
    else
      redirect_to adm_ideas_categories_path, alert: t("custom.admin.ideas.categories.destroy.cannot_be_destroyed")
    end
  end

  def order_categories
    authorize Idea::Category, :update?, policy_class: Adm::Ideas::CategoryPolicy
    Idea::Category.order_categories(params[:ordered_list])
    head :ok
  end

  private

    def category_params
      params.require(:idea_category).permit(
        :color, :icon, :idea_officer_id,
        translation_params(Idea::Category)
      )
    end
end
