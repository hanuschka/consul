require "rails_helper"

describe Kern::MapComponent, type: :component, controller: Adm::BaseController do
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  let!(:projekt) { create(:projekt) }

  def layer_names
    render_inline(described_class.new(map_location: projekt.map_location))

    value = page.find("[data-map-layers-value]", visible: :all)["data-map-layers-value"]
    JSON.parse(value).map { |layer| layer["name"] }
  end

  before { MapLayer.default.destroy_all }

  it "draws the global base layer under an admin projekt map that only has an overlay" do
    create(:map_layer, :overlay, mappable: projekt, name: "City overlay")
    create(:map_layer, name: "Aerial")

    expect(layer_names).to eq ["City overlay", "Aerial"]
  end

  it "draws the global base layer under a Leaflet map with Masterportal" do
    projekt.map_location.update!(rendering_library: :leaflet_plus_masterportal)
    create(:map_layer, :overlay, mappable: projekt, name: "City overlay")
    create(:map_layer, name: "Aerial")

    expect(layer_names).to include("City overlay", "Aerial")
  end

  it "leaves a Mapbox map on its own style" do
    projekt.map_location.update!(rendering_library: :mapbox)
    create(:map_layer, :overlay, mappable: projekt, name: "City overlay")
    create(:map_layer, name: "Aerial")

    expect(layer_names).to eq ["City overlay"]
  end

  it "keeps a projekt's own base layer" do
    create(:map_layer, mappable: projekt, name: "Own base")
    create(:map_layer, name: "Aerial")

    expect(layer_names).to eq ["Own base"]
  end
end
