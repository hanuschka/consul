class RegisteredAddressesController < ApplicationController
  skip_authorization_check

  def find
    @selected_city_id = params[:selected_city_id]
    @selected_street_id = params[:selected_street_id]
    @selected_address_id = params[:selected_address_id]
  end
end
