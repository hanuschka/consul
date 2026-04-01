class Adm::Ideas::CategoriesController < Adm::Ideas::BaseController

  def index
    @categories = policy_scope(Idea::Category, policy_scope_class: Adm::Ideas::CategoryPolicy::Scope)
                    .order(:given_order)

    @breadcrumbs = [{ name: t("adm.ideas.menu.items.categories"), icon: "category" }]
  end

  def new
    @category = Idea::Category.new
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @category = Idea::Category.find(params[:id])
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @category = Idea::Category.new(category_params)
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    if @category.save
      redirect_to adm_ideas_categories_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.ideas.categories.new.title"))
      render :new
    end
  end

  def update
    @category = Idea::Category.find(params[:id])
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    if @category.update(category_params)
      redirect_to adm_ideas_categories_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.ideas.categories.edit.title"))
      render :edit
    end
  end

  def destroy
    @category = Idea::Category.find(params[:id])
    authorize @category, policy_class: Adm::Ideas::CategoryPolicy

    if @category.safe_to_destroy?
      @category.destroy!
      redirect_to adm_ideas_categories_path, notice: t(".success")
    else
      redirect_to adm_ideas_categories_path, alert: t(".cannot_destroy")
    end
  end

  def order_categories
    authorize Idea::Category, :update?, policy_class: Adm::Ideas::CategoryPolicy
    Idea::Category.order_categories(params[:ordered_list])
    head :ok
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.ideas.categories.index.title"), url: adm_ideas_categories_path, icon: "category" },
        { name: action_title }
      ]
    end

    def category_params
      params.require(:idea_category).permit(:name, :color, :icon, :idea_officer_id)
    end
end
