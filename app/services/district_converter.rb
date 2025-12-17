class DistrictConverter < ApplicationService
  require "proj"

  def initialize(coords)
    @coords = coords
    @transform = Proj::Transformation.new("EPSG:25832", "EPSG:4326")
  end

  def call
    arr = []
    @coords.split(",").map do |pair|
      arr << convert_pair(pair)
    end
    [arr]
  end

  def convert_pair(pair)
    x, y = pair.split(' ').map(&:to_f)

    from = Proj::Coordinate.new(x: x, y: y)
    transformed = @transform.forward(from)

    [transformed.y, transformed.x]
  end
end
