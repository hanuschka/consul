class Adm::Offers::CategoriesController < Adm::Offers::BaseController
  before_action :set_kind, only: [:index, :new, :create, :order_categories]
  before_action :set_category, only: [:edit, :update, :destroy]

  def index
    authorize Offer::Category, :index?, policy_class: Adm::Offers::CategoryPolicy

    @categories = policy_scope(Offer::Category, policy_scope_class: Adm::Offers::CategoryPolicy::Scope)
                    .of_kind(@kind)
    @breadcrumbs = [{ name: t("adm.offers.categories.index.title"), icon: "category" }]
  end

  def new
    @category = Offer::Category.new(kind: @kind)
    authorize @category, policy_class: Adm::Offers::CategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @category = Offer::Category.new(category_params.merge(kind: @kind))
    authorize @category, policy_class: Adm::Offers::CategoryPolicy

    if @category.save
      redirect_to adm_offers_categories_path(kind: @kind), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.offers.categories.new.title"))
      render :new
    end
  end

  def edit
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    if @category.update(category_params)
      redirect_to adm_offers_categories_path(kind: @category.kind), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.offers.categories.edit.title"))
      render :edit
    end
  end

  def destroy
    if @category.destroy
      redirect_to adm_offers_categories_path(kind: @category.kind), notice: t(".success")
    else
      redirect_to adm_offers_categories_path(kind: @category.kind), alert: t(".cannot_destroy")
    end
  end

  def order_categories
    authorize Offer::Category, :update?, policy_class: Adm::Offers::CategoryPolicy

    Offer::Category.of_kind(@kind).order_categories(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def set_kind
      @kind = params[:kind].presence || Offer::Category::KINDS.first
      raise ActiveRecord::RecordNotFound unless @kind.in?(Offer::Category::KINDS)
    end

    def set_category
      @category = Offer::Category.find(params[:id])
      @kind = @category.kind
      authorize @category, policy_class: Adm::Offers::CategoryPolicy
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.offers.categories.index.title"),
          url: adm_offers_categories_path(kind: @kind), icon: "category" },
        { name: action_title }
      ]
    end

    def category_params
      params.require(:offer_category).permit(:name)
    end
end
