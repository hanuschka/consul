class Admin::RegisteredAddressDistrictsController < Admin::BaseController
  include MapLocationAttributes
  load_and_authorize_resource class: RegisteredAddress::District

  def index
    @registered_address_districts = RegisteredAddress::District.order(id: :desc)
  end

  def edit; end

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
        map_location_attributes: map_location_attributes
      )
    end
end
