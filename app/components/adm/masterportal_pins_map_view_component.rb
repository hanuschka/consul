class Adm::MasterportalPinsMapViewComponent < ApplicationComponent
  def initialize(projekt_phase:, pins:, total_count:, search_query: "")
    @projekt_phase = projekt_phase
    @pins = pins
    @total_count = total_count
    @search_query = search_query.to_s
  end

  def render?
    map_location&.available?
  end

  def map_location
    @projekt_phase.map_location
  end

  def feature_collection
    {
      "type" => "FeatureCollection",
      "features" => @pins.map { |pin| pin.to_map_feature(include_search_text: false) }
    }
  end

  def total_count
    @total_count.to_i
  end

  def search_query
    @search_query
  end

  attr_reader :projekt_phase
end
