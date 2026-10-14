require "rails_helper"

describe MapBoundary do
  def collection(*geometries)
    {
      "type" => "FeatureCollection",
      "features" => geometries.map { |geometry| { "type" => "Feature", "properties" => {}, "geometry" => geometry } }
    }
  end

  def square(west, south, east, north)
    { "type" => "Polygon", "coordinates" => [[[west, south], [east, south], [east, north], [west, north], [west, south]]] }
  end

  def point(lng, lat)
    { "type" => "Point", "coordinates" => [lng, lat] }
  end

  def line(*coordinates)
    { "type" => "LineString", "coordinates" => coordinates }
  end

  def circle(lng, lat, radius)
    ring = (0...60).map do |step|
      angle = 2 * Math::PI * step / 60
      [lng + radius * Math.cos(angle), lat + radius * Math.sin(angle)]
    end

    { "type" => "Polygon", "coordinates" => [ring + [ring.first]] }
  end

  let(:area) { square(7.0, 50.8, 7.2, 51.0) }

  context "without areas" do
    it "is unrestricted and accepts anything" do
      boundary = MapBoundary.new(nil)

      expect(boundary).not_to be_restricted
      expect(boundary.contains_features?(collection(point(0, 0)))).to be true
    end

    it "ignores admin pins and lines" do
      boundary = MapBoundary.new(collection(point(7.1, 50.9), line([7.0, 50.8], [7.2, 51.0])))

      expect(boundary).not_to be_restricted
    end
  end

  context "with one area" do
    let(:boundary) { MapBoundary.new(collection(area)) }

    it "is restricted" do
      expect(boundary).to be_restricted
    end

    it "accepts a pin inside and refuses one outside" do
      expect(boundary.contains_features?(collection(point(7.1, 50.9)))).to be true
      expect(boundary.contains_features?(collection(point(7.3, 50.9)))).to be false
    end

    it "accepts a pin on the edge" do
      expect(boundary.contains_features?(collection(point(7.0, 50.9)))).to be true
    end

    it "refuses a line that leaves the area" do
      expect(boundary.contains_features?(collection(line([7.05, 50.9], [7.15, 50.9])))).to be true
      expect(boundary.contains_features?(collection(line([7.05, 50.9], [7.25, 50.9])))).to be false
    end

    it "refuses a polygon that is only partly inside" do
      expect(boundary.contains_features?(collection(square(7.05, 50.85, 7.15, 50.95)))).to be true
      expect(boundary.contains_features?(collection(square(7.15, 50.85, 7.25, 50.95)))).to be false
    end

    it "checks a circle saved as a polygon by its whole outline" do
      expect(boundary.contains_features?(collection(circle(7.1, 50.9, 0.05)))).to be true
      expect(boundary.contains_features?(collection(circle(7.18, 50.9, 0.05)))).to be false
    end

    it "refuses the entry when any one of several features is outside" do
      inside = point(7.1, 50.9)
      outside = point(7.3, 50.9)

      expect(boundary.contains_features?(collection(inside, inside))).to be true
      expect(boundary.contains_features?(collection(inside, outside))).to be false
    end

    it "accepts an entry without any features" do
      expect(boundary.contains_features?(collection)).to be true
      expect(boundary.contains_features?({})).to be true
    end

    it "refuses features it cannot read" do
      broken = { "type" => "Polygon", "coordinates" => [[[7.1, 50.9]]] }

      expect(boundary.contains_features?(collection(broken))).to be false
    end
  end

  context "with several areas" do
    it "accepts placement in any of them" do
      boundary = MapBoundary.new(collection(area, square(8.0, 50.8, 8.2, 51.0)))

      expect(boundary.contains_features?(collection(point(7.1, 50.9)))).to be true
      expect(boundary.contains_features?(collection(point(8.1, 50.9)))).to be true
      expect(boundary.contains_features?(collection(point(7.6, 50.9)))).to be false
    end

    it "accepts a shape spanning two adjacent areas" do
      boundary = MapBoundary.new(collection(area, square(7.2, 50.8, 7.4, 51.0)))

      expect(boundary.contains_features?(collection(line([7.1, 50.9], [7.3, 50.9])))).to be true
    end

    it "refuses a shape spanning the gap between two areas" do
      boundary = MapBoundary.new(collection(area, square(7.3, 50.8, 7.5, 51.0)))

      expect(boundary.contains_features?(collection(line([7.1, 50.9], [7.4, 50.9])))).to be false
    end
  end
end
