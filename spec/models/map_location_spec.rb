require "rails_helper"

describe MapLocation do
  describe "#get_approximated_address" do
    let(:map_location) { build(:map_location) }

    def approximated_address(geocoder_data)
      map_location.geocoder_data = geocoder_data
      map_location.send(:get_approximated_address)
    end

    it "builds the address from the geocoder's address parts" do
      data = { "address" => { "road" => "Hauptstraße", "house_number" => "1",
                              "postcode" => "49074", "city" => "Osnabrück" }}

      expect(approximated_address(data)).to eq("Hauptstraße 1, 49074 Osnabrück")
    end

    it "returns nothing for a geocoder response that carries no address" do
      # Nominatim answers a coordinate it cannot resolve with an error payload,
      # which is present but has no address to read.
      expect(approximated_address("error" => "Unable to geocode")).to be_nil
    end

    it "returns nothing when the geocoder returned nothing at all" do
      expect(approximated_address(nil)).to be_nil
      expect(approximated_address({})).to be_nil
    end
  end
end
