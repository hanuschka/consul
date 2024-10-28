class DeficiencyReportManagement::CategoriesController < DeficiencyReportManagement::BaseController
  include Translatable
  load_and_authorize_resource :category, class: "DeficiencyReport::Category", except: :show

  def index
    @categories = DeficiencyReport::Category.all
  end

  def new
    @df_officers = DeficiencyReport::Officer.all
  end

  def edit
    @df_officers = DeficiencyReport::Officer.all
  end

  def create
    @category = DeficiencyReport::Category.new(category_params)

    if @category.save
      redirect_to deficiency_report_management_categories_path
    else
      render :new
    end
  end

  def update
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
      :deficiency_report_officer_id,
      translation_params(DeficiencyReport::Category)
    )
  end
end
