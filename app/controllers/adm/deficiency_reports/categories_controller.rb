class Adm::DeficiencyReports::CategoriesController < Adm::DeficiencyReports::BaseController
  include Translatable

  def index
    @categories = policy_scope(DeficiencyReport::Category, policy_scope_class: Adm::DeficiencyReports::CategoryPolicy::Scope)
                    .order(:given_order)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.categories") }]
  end

  def new
    @category = DeficiencyReport::Category.new
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @category = DeficiencyReport::Category.find(params[:id])
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy
    set_current_default_responsible

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @category = DeficiencyReport::Category.new(category_params)
    authorize @category, policy_class: Adm::DeficiencyReports::CategoryPolicy
    update_default_responsible

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
    update_default_responsible

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
    DeficiencyReport::Category.order_categories(params[:ordered_list])
    head :ok
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.categories.index.title"), url: adm_deficiency_reports_categories_path },
        { name: action_title }
      ]
    end

    def category_params
      params.require(:deficiency_report_category).permit(
        :color, :icon, :warning_text,
        translation_params(DeficiencyReport::Category)
      )
    end

    def set_current_default_responsible
      if @category.default_responsible.is_a?(DeficiencyReport::Officer)
        @category.default_officer_id = @category.default_responsible.id
      elsif @category.default_responsible.is_a?(DeficiencyReport::OfficerGroup)
        @category.default_officer_group_id = @category.default_responsible.id
      end
    end

    def update_default_responsible
      if params[:deficiency_report_category]["default_officer_id"].present?
        @category.default_responsible = DeficiencyReport::Officer.find(params[:deficiency_report_category]["default_officer_id"])
      elsif params[:deficiency_report_category]["default_officer_group_id"].present?
        @category.default_responsible = DeficiencyReport::OfficerGroup.find(params[:deficiency_report_category]["default_officer_group_id"])
      end
    end
end
