require "rails_helper"

describe Offers::OverviewMapService do
  def pin(offer, latitude, longitude)
    offer.create_map_location!(
      latitude: 1.0, longitude: 1.0, zoom: 10, skip_masterportal_geocoding: true,
      features: { type: "FeatureCollection",
                  features: [{ type: "Feature", geometry: { type: "Point", coordinates: [longitude, latitude] },
                               properties: {} }] }
    )
    offer
  end

  it "shows a marker for every offer of the filtered result that has a pin" do
    north = create(:offer_category, :social_area, name: "Nord")
    shown = pin(create(:offer, title: "Schwimmen", categories: [create(:offer_category, :offer_type), north]),
                50.9, 11.6)
    pin(create(:offer, title: "Lesecafé"), 50.8, 11.5)
    create(:offer, title: "Online-Kurs", categories: [create(:offer_category, :offer_type), north])

    scope = OffersQuery.new(Offer.all, social_area: [north.id]).call
    map = described_class.new(scope)

    expect(map.markers[:features].map { |feature| feature[:properties][:id] }).to eq [shown.id]
    expect(map.markers[:features].first[:geometry][:coordinates]).to eq [11.6, 50.9]
    expect(map.center).to eq(latitude: 50.9, longitude: 11.6)
  end

  it "frames all markers when there are several" do
    pin(create(:offer), 50.9, 11.6)
    pin(create(:offer), 50.8, 11.5)

    map = described_class.new(Offer.all)

    expect(map.bounds).to eq(south: 50.8, west: 11.5, north: 50.9, east: 11.6)
    expect(map.center).to be_nil
  end

  it "has nothing to show without pinned offers" do
    create(:offer)

    expect(described_class.new(Offer.all).show?).to be false
  end
end
