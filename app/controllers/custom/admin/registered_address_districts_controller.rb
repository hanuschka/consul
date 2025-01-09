class Admin::RegisteredAddressDistrictsController < Admin::BaseController
  include MapLocationAttributes
  load_and_authorize_resource class: RegisteredAddress::District

  def index
    @registered_address_districts = RegisteredAddress::District.order(id: :desc)
  end

  def edit
    unless @registered_address_district.map_location
      @registered_address_district.build_map_location(
        longitude: Setting["map.longitude"],
        latitude: Setting["map.latitude"],
        zoom: Setting["map.zoom"]
      )
    end
  end

  def update
    if @registered_address_district.update(district_params)
      redirect_to admin_registered_address_districts_path, notice: t("custom.admin.registered_address_districts.update.success")
    else
      render :edit
    end
  end

  private

    def district_params
      params.require(:registered_address_district).permit(
        map_location_attributes: nested_map_location_attributes
      )
    end
end
