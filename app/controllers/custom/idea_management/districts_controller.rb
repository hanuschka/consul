class IdeaManagement::DistrictsController < IdeaManagement::BaseController
  skip_authorization_check if: -> { current_user.administrator? || current_user.idea_manager? }

  def index
    @districts = RegisteredAddress::District.all
  end

  def edit
    @district = RegisteredAddress::District.find(params[:id])
  end

  def update
    @district = RegisteredAddress::District.find(params[:id])
    @district.update!(registered_address_district_params)
    redirect_to idea_management_districts_path
  end

  private

    def registered_address_district_params
      params.require(:registered_address_district).permit(:idea_officer_id)
    end
end
