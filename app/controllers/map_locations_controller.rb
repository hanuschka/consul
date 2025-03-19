class MapLocationsController < ApplicationController
  def get_coordinates
    authorize! :get_coordinates, MapLocation

    address_query = params[:address_query]&.gsub(/[^\w\s,.-]/, "")

    if address_query.present?
      @matching_addresses = Geocoder.search(address_query, params: geocoder_extra_query_params).first(8).map do |address|
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

  def update_screenshot
    authorize! :update_screenshot, MapLocation

    @map_location = MapLocation.find(params[:id])
    @map_location.screenshot.purge if @map_location.screenshot.attached?

    if @map_location.screenshot.attach(params[:screenshot])
      render json: { success: true }
    else
      render json: { success: false, errors: @map_location.errors.full_messages }
    end
  end

  private

    def geocoder_extra_query_params
      Geocoder.config[:lookup] == :nominatim ? { viewbox: bounding_box.flatten.join(","), bounded: 1 } : {}
    end

    def bounding_box
      lat = Setting["map.latitude"].to_f
      lon = Setting["map.longitude"].to_f

      radius_lat = 20.0 / 111.12
      radius_lon = 20.0 / (111.12 * Math.cos(lat * Math::PI / 180))

      min_lat = lat - radius_lat
      max_lat = lat + radius_lat
      min_lon = lon - radius_lon
      max_lon = lon + radius_lon

      [min_lon, min_lat, max_lon, max_lat]
    end
end
