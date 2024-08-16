class MapLocationsController < ApplicationController
  def get_coordinates
    authorize! :get_coordinates, MapLocation

    address_query = params[:address_query]&.gsub(/[^\w\s,.-]/, "")

    if address_query.present?
      @matching_addresses = Geocoder.search(address_query).first(8).map do |address|
        {
          address: address.address,
          coordinates: address.coordinates
        }
      end
    end

    respond_to do |format|
      format.json { render json: @matching_addresses }
    end
  end
end
