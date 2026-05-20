class Adm::Projekts::ProjektPointOfInterestCategoriesController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_category, only: %i[edit update destroy]

  def new
    @category = @projekt_phase.projekt_point_of_interest_categories.new
    authorize [:adm, :projekts, @category]

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @category = @projekt_phase.projekt_point_of_interest_categories.new(category_params)
    authorize [:adm, :projekts, @category]

    if @category.save
      purge_icon_image_if_requested
      redirect_to projekt_point_of_interest_categories_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_point_of_interest_categories.new.title"))
      render :new
    end
  end

  def edit
    authorize [:adm, :projekts, @category]

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @category]

    if @category.update(category_params)
      purge_icon_image_if_requested
      redirect_to projekt_point_of_interest_categories_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_point_of_interest_categories.edit.title"))
      render :edit
    end
  end

  def destroy
    authorize [:adm, :projekts, @category]

    if @category.projekt_point_of_interest_pins.any?
      redirect_to projekt_point_of_interest_categories_adm_projekts_phase_path(@projekt_phase),
        alert: t(".has_pins")
    else
      @category.destroy!
      redirect_to projekt_point_of_interest_categories_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    end
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_category
      @category = ProjektPointOfInterestCategory.find(params[:id])
    end

    def category_params
      params.require(:projekt_point_of_interest_category).permit(:name, :color, :icon, :icon_image)
    end

    def purge_icon_image_if_requested
      return if params.dig(:projekt_point_of_interest_category, :remove_icon_image) != "1"

      @category.icon_image.purge
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: details_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.projekt_point_of_interest_categories.title"), url: projekt_point_of_interest_categories_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
