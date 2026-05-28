class ParticapationStats::HeatmapComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def render?
    coordinates.any?
  end

  def coordinates_json
    coordinates.to_json
  end

  def map_center
    query.map_center
  end

  def map_zoom
    query.map_zoom
  end

  private

    def coordinates
      query.coordinates
    end

    def query
      @query ||= ProjektPhaseStats::HeatmapQuery.new(@projekt_phase)
    end
end
