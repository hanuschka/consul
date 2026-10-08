class Polls::MapPointBoundary < MapBoundary
  def initialize(question)
    super(question.map_location&.to_geo_json)
  end
end
