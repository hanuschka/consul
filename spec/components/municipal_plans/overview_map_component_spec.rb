require "rails_helper"

describe MunicipalPlans::OverviewMapComponent, type: :component do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  let(:areas) { { type: "FeatureCollection", features: [{ type: "Feature" }] } }
  let(:markers) { { type: "FeatureCollection", features: [] } }
  let(:bounds) { { south: 50.88, west: 11.50, north: 50.97, east: 11.66 } }
  let(:overview_map) do
    instance_double(MunicipalPlans::OverviewMapService, show?: true, bounds: bounds, areas: areas,
                                                        markers: markers)
  end

  def render_map
    render_inline(MunicipalPlans::OverviewMapComponent.new(overview_map: overview_map))
  end

  def map_container
    page.find(".js-municipal-plans-map-container")
  end

  def json(attribute)
    JSON.parse(map_container["data-#{attribute}"])
  end

  it "renders nothing when there are no Ortsteil areas" do
    allow(overview_map).to receive(:show?).and_return(false)

    render_map

    expect(page).not_to have_css(".js-municipal-plans-map")
  end

  it "starts fitted to the Ortsteile and carries areas and markers" do
    render_map

    expect(json("bounds")).to eq("south" => 50.88, "west" => 11.50, "north" => 50.97, "east" => 11.66)
    expect(json("areas")["features"].size).to eq 1
    expect(json("markers")["features"]).to be_empty
  end

  it "stays out of the shared map stack" do
    render_map

    expect(map_container["data-map"]).to be_nil
  end

  it "is labelled and described for screen readers" do
    render_map

    note = page.find("##{map_container["aria-describedby"]}", visible: :all)

    expect(map_container["role"]).to eq "region"
    expect(map_container["aria-label"]).to eq I18n.t("custom.municipal_plans.index.overview_map.region_label")
    expect(note.text(:all)).to eq I18n.t("custom.municipal_plans.index.overview_map.note")
  end

  describe "base map from the default map location" do
    it "uses Mapbox with the default map's style when the default map is Mapbox" do
      MapLocation.default.update!(rendering_library: "mapbox", mapbox_style_id: "mapbox://styles/jena/abc")
      allow(ExternalApiKey).to receive(:mapbox_public_token).and_return("pk.test")

      render_map

      expect(map_container["data-library"]).to eq "mapbox"
      expect(map_container["data-mapbox-token"]).to eq "pk.test"
      expect(map_container["data-mapbox-style"]).to eq "mapbox://styles/jena/abc"
      expect(map_container["data-tile-layer"]).to be_nil
    end

    it "falls back to Leaflet for a Virtualcity default map" do
      MapLocation.default.update!(rendering_library: "virtualcity")

      render_map

      expect(map_container["data-library"]).to eq "leaflet"
    end

    it "uses the default map's base layer for Leaflet" do
      MapLocation.default.update!(rendering_library: "leaflet")
      MapLayer.create!(name: "Stadtplan", provider: "https://geo.jena.example/wms", protocol: "wms",
                       layer_names: "stadtplan", base: true, attribution: "Stadt Jena")

      render_map

      expect(json("tile-layer")).to include("protocol" => "wms", "provider" => "https://geo.jena.example/wms",
                                            "layer_names" => "stadtplan", "attribution" => "Stadt Jena")
    end

    it "leaves the tile layer empty for the OpenStreetMap fallback when no base layer exists" do
      MapLocation.default.update!(rendering_library: "leaflet")

      render_map

      expect(map_container["data-tile-layer"]).to be_nil
    end
  end
end
