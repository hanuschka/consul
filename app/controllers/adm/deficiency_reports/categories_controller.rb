class Adm::DeficiencyReports::CategoriesController < Adm::DeficiencyReports::BaseController
  include Translatable

  def index
    @categories = policy_scope(DeficiencyReport::Category, policy_scope_class: Adm::DeficiencyReports::CategoryPolicy::Scope)
                    .includes(:subcategories)
                    .order(:given_order)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.categories"), icon: "category" }]
  end

  def new
    @category = DeficiencyReport::Category.new
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @category = DeficiencyReport::Category.find(params[:id])
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @category = DeficiencyReport::Category.new(category_params)
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy
    @category.default_responsible = resolve_responsible

    if @category.save
      redirect_to adm_deficiency_reports_categories_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.categories.new.title"))
      render :new
    end
  end

  def update
    @category = DeficiencyReport::Category.find(params[:id])
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy
    @category.default_responsible = resolve_responsible

    if @category.update(category_params)
      redirect_to adm_deficiency_reports_categories_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.categories.edit.title"))
      render :edit
    end
  end

  def destroy
    @category = DeficiencyReport::Category.find(params[:id])
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy

    if @category.safe_to_destroy?
      @category.destroy!
      redirect_to adm_deficiency_reports_categories_path, notice: t(".success")
    else
      redirect_to adm_deficiency_reports_categories_path, alert: t(".cannot_destroy")
    end
  end

  def order_categories
    authorize DeficiencyReport::Category, :update?, policy_class: Adm::DeficiencyReports::CategoryPolicy
    DeficiencyReport::Category.order_categories(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.categories.index.title"), url: adm_deficiency_reports_categories_path, icon: "category" },
        { name: action_title }
      ]
    end

    def category_params
      params.require(:deficiency_report_category).permit(
        :name, :color, :icon, :warning_text
      )
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
