require "rails_helper"

describe Shared::MapComponent do
  let(:projekt) { create(:projekt) }

  it "uses a stable map container id by default" do
    render_inline described_class.new(mappable: projekt)

    expect(page.find("div.map_location")[:id]).to eq("map_projekt_#{projekt.id}")
  end

  it "appends instance_suffix so several map embeds on one page get unique ids" do
    render_inline described_class.new(mappable: projekt, instance_suffix: "abc123")

    expect(page.find("div.map_location")[:id]).to eq("map_projekt_#{projekt.id}_abc123")
  end
end
