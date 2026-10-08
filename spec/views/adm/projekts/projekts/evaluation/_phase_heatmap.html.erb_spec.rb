require "rails_helper"

describe "adm/projekts/projekts/evaluation/_phase_heatmap" do
  let!(:projekt) { create(:projekt) }
  let(:phase) do
    { "phase_id" => nil, "full_stats" => { "heatmap" => { "coordinates" => [[54.78, 9.43]] }}}
  end

  before do
    MapLayer.default.destroy_all
    assign(:projekt, projekt)
  end

  def base_layer_value
    render partial: "adm/projekts/projekts/evaluation/phase_heatmap",
           locals: { phase: phase, accent: nil, accent_light: nil }

    attribute = "data-adm--evaluation-heatmap-base-layer-value"
    JSON.parse(Nokogiri::HTML(rendered).at_css("[#{attribute}]")[attribute])
  end

  it "hands the configured base layer to the heatmap" do
    create(:map_layer, provider: "https://wms.example.org/service", layer_names: "aerial")

    expect(base_layer_value).to include("protocol" => "wms",
                                        "provider" => "https://wms.example.org/service",
                                        "layer_names" => "aerial")
  end

  it "hands nothing when no base layer is configured" do
    expect(base_layer_value).to eq({})
  end
end
