module ProjektPointOfInterestCategoriesAdminActions
  extend ActiveSupport::Concern

  included do
    before_action :set_projekt_phase
    before_action :set_category, only: [:edit, :update, :destroy]

    respond_to :js, only: [:new, :edit, :create]
  end

  def new
    @category = @projekt_phase.projekt_point_of_interest_categories.new
    authorize!(:new, @category)

    render "custom/admin/projekt_phases/projekt_point_of_interest_categories/new"
  end

  def create
    @category = @projekt_phase.projekt_point_of_interest_categories.new(category_params)
    authorize!(:create, @category)

    if @category.save
      redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektPointOfInterestCategory]), notice: t("admin.settings.flash.updated")
    else
      render "custom/admin/projekt_phases/projekt_point_of_interest_categories/new"
    end
  end

  def edit
    authorize!(:edit, @category)

    render "custom/admin/projekt_phases/projekt_point_of_interest_categories/edit"
  end

  def update
    authorize!(:update, @category)

    if @category.update(category_params)
      redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektPointOfInterestCategory]),
        notice: t("custom.admin.projekt_phases.point_of_interest_phases.categories.update.notice")
    else
      render :edit
    end
  end

  def destroy
    authorize!(:destroy, @category)

    if @category.projekt_point_of_interest_pins.any?
      redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektPointOfInterestCategory]),
        alert: t("custom.admin.projekt_phases.point_of_interest.categories.destroy.notice")
    else
      @category.destroy!
      redirect_to polymorphic_path([@namespace, @projekt_phase, ProjektPointOfInterestCategory]),
        notice: t("custom.admin.projekt_phases.point_of_interest.categories.destroy.error")
    end
  end

  private

  def set_projekt_phase
    @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
  end

  def set_category
    @category = @projekt_phase.projekt_point_of_interest_categories.find(params[:id])
  end

  def category_params
    params.require(:projekt_point_of_interest_category).permit(:name, :color, :icon)
  end

  def set_namespace
    @namespace = params[:controller].split("/").first.to_sym
  end
end
