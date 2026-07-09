class ProjektPhaseStats::HeatmapQuery < ApplicationService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    {
      coordinates: coordinates,
      map_center: map_center,
      map_zoom: map_zoom
    }
  end

  def coordinates
    @coordinates ||= map_location_rows.flat_map do |features, latitude, longitude|
      extract_coordinates_from_features(features, latitude, longitude)
    end.compact
  end

  def map_center
    return default_center if coordinates.empty?

    avg_lat = coordinates.sum { |c| c[0] } / coordinates.size
    avg_lng = coordinates.sum { |c| c[1] } / coordinates.size
    [avg_lat, avg_lng]
  end

  def map_zoom
    @projekt_phase.map_location&.zoom || Setting["map.zoom"] || 12
  end

  private

    def extract_coordinates_from_features(features, latitude, longitude)
      return [[latitude, longitude, 1.0]] if features.blank?

      coords = []

      if features.is_a?(Hash) && features["type"] == "FeatureCollection"
        features["features"]&.each do |feature|
          coord = extract_point_from_feature(feature)
          coords << coord if coord
        end
      elsif features.is_a?(Hash) && features["type"] == "Feature"
        coord = extract_point_from_feature(features)
        coords << coord if coord
      end

      coords.presence || [[latitude, longitude, 1.0]]
    end

    def extract_point_from_feature(feature)
      geometry = feature["geometry"]
      return nil unless geometry

      case geometry["type"]
      when "Point"
        lng, lat = geometry["coordinates"]
        [lat, lng, 1.0] if lat && lng
      when "Polygon", "MultiPolygon"
        centroid = calculate_centroid(geometry)
        [centroid[1], centroid[0], 1.0] if centroid
      end
    end

    def calculate_centroid(geometry)
      coords = case geometry["type"]
               when "Polygon"
                 geometry["coordinates"].first
               when "MultiPolygon"
                 geometry["coordinates"].first&.first
               end

      return nil if coords.blank?

      lng_sum = coords.sum { |c| c[0] }
      lat_sum = coords.sum { |c| c[1] }
      [lng_sum / coords.size, lat_sum / coords.size]
    end

    def map_location_rows
      @map_location_rows ||= fetch_map_location_rows
    end

    def fetch_map_location_rows
      case @projekt_phase
      when ProjektPhase::ProposalPhase
        MapLocation
          .where(
            mappable_type: "Proposal",
            mappable_id: @projekt_phase.proposals.base_selection.select(:id)
          )
          .pluck(:features, :latitude, :longitude)
      when ProjektPhase::BudgetPhase
        return [] if @projekt_phase.budget.blank?

        MapLocation
          .where(
            mappable_type: "Budget::Investment",
            mappable_id: @projekt_phase.budget.investments.select(:id)
          )
          .pluck(:features, :latitude, :longitude)
      else
        []
      end
    end

    def default_center
      [
        Setting["map.latitude"].to_f,
        Setting["map.longitude"].to_f
      ]
    end
end
