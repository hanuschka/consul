class MapLocationsController < ApplicationController
  MIN_SCREENSHOT_BYTES = 5_000
  ALLOWED_SCREENSHOT_CONTENT_TYPES = ["image/jpeg", "image/png", "image/webp"].freeze

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
    uploaded = params[:screenshot]

    if invalid_screenshot?(uploaded)
      render json: { success: false, errors: ["Screenshot blob missing, too small, or wrong type"] },
             status: :unprocessable_entity
      return
    end

    @map_location.screenshot.attach(uploaded)

    if @map_location.screenshot.attached?
      render json: { success: true }
    else
      render json: { success: false, errors: @map_location.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private

    def invalid_screenshot?(uploaded)
      return true if uploaded.blank?
      return true if !uploaded.respond_to?(:size)
      return true if uploaded.size < MIN_SCREENSHOT_BYTES
      return true if !valid_screenshot_content_type?(uploaded)

      false
    end

    def valid_screenshot_content_type?(uploaded)
      return false if !uploaded.respond_to?(:content_type)

      ALLOWED_SCREENSHOT_CONTENT_TYPES.include?(uploaded.content_type)
    end

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
