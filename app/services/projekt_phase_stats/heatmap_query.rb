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
    @coordinates ||= resources_with_map_location.flat_map do |resource|
      extract_coordinates_from_features(resource.map_location)
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

    def extract_coordinates_from_features(map_location)
      return [] unless map_location

      features = map_location.features
      return [[map_location.latitude, map_location.longitude, 1.0]] if features.blank?

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

      coords.presence || [[map_location.latitude, map_location.longitude, 1.0]]
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

    def resources_with_map_location
      case @projekt_phase
      when ProjektPhase::ProposalPhase
        @projekt_phase.proposals.base_selection.joins(:map_location).includes(:map_location)
      when ProjektPhase::BudgetPhase
        return [] if @projekt_phase.budget.blank?

        @projekt_phase.budget.investments.joins(:map_location).includes(:map_location)
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
