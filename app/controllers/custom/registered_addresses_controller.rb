class RegisteredAddressesController < ApplicationController
  skip_authorization_check

  def find
    @selected_city_id = params[:selected_city_id]
    @selected_street_id = params[:selected_street_id]
    @selected_address_id = params[:selected_address_id]
  end

  def streets
    city = RegisteredAddress::City.find(params[:city_id])
    streets = city.registered_address_streets
      .map { |s| { label: s.name_with_plz, value: s.id } }

    render json: streets
  end

  def addresses
    street = RegisteredAddress::Street.find(params[:street_id])
    addresses = street.registered_addresses
      .sort_by { |a| [a.street_number.to_i, a.street_number_extension.to_s] }
      .map { |a| { label: a.formatted_name, value: a.id } }

    render json: addresses
  end

  private

    def store_location_for(resource_or_scope, location)
      # Prevent storing location in this controller
    end
end
