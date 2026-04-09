class Adm::Ideas::DistrictsController < Adm::Ideas::BaseController
  def index
    @districts = policy_scope(::RegisteredAddress::District, policy_scope_class: Adm::Ideas::DistrictPolicy::Scope)

    @breadcrumbs = [{ name: t("adm.ideas.menu.items.districts"), icon: "location_city" }]
  end

  def edit
    @district = ::RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::Ideas::DistrictPolicy

    @breadcrumbs = breadcrumbs_for_action(@district.name)
  end

  def update
    @district = ::RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::Ideas::DistrictPolicy

    @district.update!(district_params)
    redirect_to adm_ideas_districts_path, notice: t(".success")
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.ideas.districts.index.title"), url: adm_ideas_districts_path, icon: "location_city" },
        { name: action_title }
      ]
    end

    def district_params
      params.require(:registered_address_district).permit(:idea_officer_id)
    end
end
