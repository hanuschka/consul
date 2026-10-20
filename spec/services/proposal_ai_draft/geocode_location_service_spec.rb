require "rails_helper"

describe ProposalAiDraft::GeocodeLocationService do
  let(:phase) { create(:proposal_phase) }
  let(:proposal) { create(:proposal, projekt_phase: phase) }
  let(:area) do
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "properties" => {},
        "geometry" => {
          "type" => "Polygon",
          "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]]
        }
      }]
    }
  end

  def geocode_to(latitude, longitude)
    allow(ProposalAiDraft::LocationLookupService).to receive(:call)
      .and_return("latitude" => latitude, "longitude" => longitude)

    described_class.call(mappable: proposal, location_name: "Marktplatz")
    proposal.reload.map_location
  end

  before { phase.reload.map_location.update!(features: area) }

  context "when the phase restricts entries to its marked areas" do
    before do
      phase.settings.find_by!(key: "feature.form.restrict_map_features_to_marked_areas").update!(value: "active")
    end

    it "pins a place inside the areas" do
      expect(geocode_to(50.9, 7.1)).to be_present
    end

    it "leaves the draft without a pin for a place outside the areas" do
      expect(geocode_to(50.9, 7.5)).to be_nil
    end
  end

  it "pins a place outside the areas while the phase setting is off" do
    expect(geocode_to(50.9, 7.5)).to be_present
  end
end
