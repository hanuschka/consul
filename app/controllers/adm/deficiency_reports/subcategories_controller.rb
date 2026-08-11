class Adm::DeficiencyReports::SubcategoriesController < Adm::DeficiencyReports::BaseController
  include Translatable

  before_action :load_category

  def index
    @subcategories = policy_scope(@category.subcategories,
      policy_scope_class: Adm::DeficiencyReports::SubcategoryPolicy::Scope)

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def new
    @subcategory = @category.subcategories.new
    authorize @subcategory, policy_class: Adm::DeficiencyReports::SubcategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @subcategory = @category.subcategories.find(params[:id])
    authorize @subcategory, policy_class: Adm::DeficiencyReports::SubcategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @subcategory = @category.subcategories.new(subcategory_params)
    authorize @subcategory, policy_class: Adm::DeficiencyReports::SubcategoryPolicy
    @subcategory.default_responsible = resolve_responsible

    if @subcategory.save
      redirect_to adm_deficiency_reports_category_subcategories_path(@category), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.subcategories.new.title"))
      render :new
    end
  end

  def update
    @subcategory = @category.subcategories.find(params[:id])
    authorize @subcategory, policy_class: Adm::DeficiencyReports::SubcategoryPolicy
    @subcategory.default_responsible = resolve_responsible

    if @subcategory.update(subcategory_params)
      redirect_to adm_deficiency_reports_category_subcategories_path(@category), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.subcategories.edit.title"))
      render :edit
    end
  end

  def destroy
    @subcategory = @category.subcategories.find(params[:id])
    authorize @subcategory, policy_class: Adm::DeficiencyReports::SubcategoryPolicy

    if @subcategory.safe_to_destroy?
      @subcategory.destroy!
      redirect_to adm_deficiency_reports_category_subcategories_path(@category), notice: t(".success")
    else
      redirect_to adm_deficiency_reports_category_subcategories_path(@category), alert: t(".cannot_destroy")
    end
  end

  def order_subcategories
    authorize DeficiencyReport::Subcategory, :update?,
      policy_class: Adm::DeficiencyReports::SubcategoryPolicy
    DeficiencyReport::Subcategory.order_subcategories(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def load_category
      @category = DeficiencyReport::Category.find(params[:category_id])
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.categories.index.title"),
          url: adm_deficiency_reports_categories_path, icon: "category" },
        { name: @category.name,
          url: adm_deficiency_reports_category_subcategories_path(@category) },
        { name: action_title }
      ]
    end

    def subcategory_params
      params.require(:deficiency_report_subcategory).permit(:name)
    end

    def resolve_responsible
      return nil if params[:default_responsible].blank?

      type, id = params[:default_responsible].split(":")
      case type
      when "OfficerGroup" then DeficiencyReport::OfficerGroup.find(id)
      when "Officer" then DeficiencyReport::Officer.find(id)
      end
    end
end
