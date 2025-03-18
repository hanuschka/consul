class DeficiencyReportManagement::CategoriesController < DeficiencyReportManagement::BaseController
  include Translatable
  load_and_authorize_resource :category, class: "DeficiencyReport::Category", except: :show

  def index
    @categories = DeficiencyReport::Category.all.order(:given_order)
  end

  def new; end

  def edit
    set_current_default_responsible
  end

  def create
    @category = DeficiencyReport::Category.new(category_params)
    update_default_responsible

    if @category.save
      redirect_to deficiency_report_management_categories_path
    else
      render :new
    end
  end

  def update
    update_default_responsible

    if @category.update(category_params)
      redirect_to deficiency_report_management_categories_path
    else
      render :edit
    end
  end

  def destroy
    if @category.safe_to_destroy?
      @category.destroy!
      redirect_to deficiency_report_management_categories_path, notice: t('custom.admin.deficiency_reports.categories.destroy.destroyed_successfully')
    else
      redirect_to deficiency_report_management_categories_path, alert: t('custom.admin.deficiency_reports.categories.destroy.cannot_be_destroyed')
    end
  end

  def order_categories
    DeficiencyReport::Category.order_categories(params[:ordered_list])
    head :ok
  end

  private

    def category_params
      params.require(:deficiency_report_category).permit(
        :color, :icon,
        :warning_text,
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
