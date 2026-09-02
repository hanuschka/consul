require "rails_helper"

describe Polls::MapPointBoundary do
  let(:question) { create(:poll_question, :map_points) }

  # A square roughly covering 50.8..51.0 N, 7.0..7.2 E
  def polygon_collection
    {
      "type" => "FeatureCollection",
      "features" => [
        {
          "type" => "Feature",
          "properties" => {},
          "geometry" => {
            "type" => "Polygon",
            "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]]
          }
        }
      ]
    }
  end

  def point_collection
    {
      "type" => "FeatureCollection",
      "features" => [
        {
          "type" => "Feature",
          "properties" => {},
          "geometry" => { "type" => "Point", "coordinates" => [7.1, 50.9] }
        }
      ]
    }
  end

  def add_boundary(features)
    question.create_map_location!(
      features: features,
      latitude: 50.9,
      longitude: 7.1,
      zoom: 13,
      rendering_library: :leaflet,
      skip_masterportal_geocoding: true
    )
    question.reload
  end

  context "when the question has no map location" do
    it "is unrestricted and accepts any point" do
      boundary = described_class.new(question)

      expect(boundary).not_to be_restricted
      expect(boundary.contains?(50.9, 7.1)).to be true
      expect(boundary.contains?(-33.8, 151.2)).to be true
    end
  end

  context "when the question has a polygon boundary" do
    before { add_boundary(polygon_collection) }

    it "is restricted" do
      expect(described_class.new(question)).to be_restricted
    end

    it "accepts a point inside the polygon" do
      expect(described_class.new(question).contains?(50.9, 7.1)).to be true
    end

    it "rejects a point outside the polygon" do
      boundary = described_class.new(question)

      expect(boundary.contains?(50.9, 8.5)).to be false
      expect(boundary.contains?(48.1, 11.6)).to be false
    end

    it "accepts a point on the boundary edge" do
      expect(described_class.new(question).contains?(50.8, 7.1)).to be true
    end

    it "accepts coordinates given as strings" do
      expect(described_class.new(question).contains?("50.9", "7.1")).to be true
    end
  end

  context "when the map location holds no polygon" do
    before { add_boundary(point_collection) }

    it "does not restrict placement" do
      boundary = described_class.new(question)

      expect(boundary).not_to be_restricted
      expect(boundary.contains?(48.1, 11.6)).to be true
    end
  end
end
