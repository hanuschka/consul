class Offers::OverviewMapService
  def initialize(filtered_scope)
    @filtered_scope = filtered_scope
  end

  def show?
    markers[:features].any?
  end

  def markers
    @markers ||= {
      type: "FeatureCollection",
      features: pinned_offers.filter_map do |offer|
        pin = offer.map_location.pin_coordinates
        next if pin.blank?

        {
          type: "Feature",
          geometry: { type: "Point", coordinates: [pin[:longitude].to_f, pin[:latitude].to_f] },
          properties: { id: offer.id, title: offer.title, url: url_helpers.offer_path(offer) }
        }
      end
    }
  end

  def bounds
    @bounds ||= if positions.uniq.size > 1
                  longitudes, latitudes = positions.transpose

                  { south: latitudes.min, west: longitudes.min, north: latitudes.max, east: longitudes.max }
                end
  end

  def center
    @center ||= if positions.uniq.one?
                  longitude, latitude = positions.first

                  { latitude: latitude, longitude: longitude }
                end
  end

  private

    def positions
      @positions ||= markers[:features].map { |feature| feature[:geometry][:coordinates] }
    end

    def pinned_offers
      Offer.where(id: @filtered_scope.unscope(:select, :order).select(:id))
           .joins(:map_location)
           .includes(:map_location, :translations)
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end
end
