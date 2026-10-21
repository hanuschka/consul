require "rails_helper"

describe "Marked areas check", type: :request do
  let(:phase) { create(:proposal_phase) }

  def collection(*geometries)
    {
      "type" => "FeatureCollection",
      "features" => geometries.map { |geometry| { "type" => "Feature", "properties" => {}, "geometry" => geometry } }
    }
  end

  let(:area) do
    collection("type" => "Polygon",
               "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]])
  end

  def check(features)
    post marked_areas_check_projekt_phase_path(phase), params: { features: features }, as: :json
    response.parsed_body["inside"]
  end

  def restrict
    phase.settings.find_by!(key: "feature.form.restrict_map_features_to_marked_areas").update!(value: "active")
    phase.reload.map_location.update!(features: area)
  end

  context "when the phase restricts entries to its marked areas" do
    before { restrict }

    it "answers inside for a pin inside the areas" do
      expect(check(collection("type" => "Point", "coordinates" => [7.1, 50.9]).to_json)).to be true
    end

    it "answers outside for a pin outside the areas" do
      expect(check(collection("type" => "Point", "coordinates" => [7.5, 50.9]).to_json)).to be false
    end

    it "answers outside for a line leaving the areas" do
      line = { "type" => "LineString", "coordinates" => [[7.1, 50.9], [7.5, 50.9]] }

      expect(check(collection(line).to_json)).to be false
    end

    it "answers outside for features it cannot read" do
      expect(check("not json")).to be false
    end

    it "answers outside for an oversized payload" do
      expect(check("x" * (MarkedAreasChecksController::MAX_FEATURES_LENGTH + 1))).to be false
    end

    it "answers inside when the areas cannot be tested" do
      allow_any_instance_of(MapBoundary).to receive(:usable?).and_return(false)

      expect(check(collection("type" => "Point", "coordinates" => [7.5, 50.9]).to_json)).to be true
    end
  end

  it "answers inside while the phase setting is off" do
    phase.reload.map_location.update!(features: area)

    expect(check(collection("type" => "Point", "coordinates" => [7.5, 50.9]).to_json)).to be true
  end
end
