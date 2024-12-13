class RegisteredAddressesController < ApplicationController
  skip_authorization_check

  def find
    @selected_city_id = params[:selected_city_id]
    @selected_street_id = params[:selected_street_id]
    @selected_address_id = params[:selected_address_id]
  end

  private

    def store_location_for(resource_or_scope, location)
      # Prevent storing location in this controller
    end
end
