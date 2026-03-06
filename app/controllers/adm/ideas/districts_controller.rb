class Adm::Ideas::DistrictsController < Adm::Ideas::BaseController
  def index
    @districts = policy_scope(RegisteredAddress::District, policy_scope_class: Adm::Ideas::DistrictPolicy::Scope)
  end

  def edit
    @district = RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::Ideas::DistrictPolicy
  end

  def update
    @district = RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::Ideas::DistrictPolicy

    @district.update!(district_params)
    redirect_to adm_ideas_districts_path
  end

  private

    def district_params
      params.require(:registered_address_district).permit(:idea_officer_id)
    end
end
