require "rails_helper"

describe MapLayer do
  describe ".for_mappable" do
    let!(:projekt) { create(:projekt) }

    before { MapLayer.default.destroy_all }

    it "appends the global base layers to a projekt that only has overlays" do
      overlay = create(:map_layer, :overlay, mappable: projekt)
      global_base = create(:map_layer)
      create(:map_layer, :overlay)

      expect(MapLayer.for_mappable(projekt)).to eq [overlay, global_base]
    end

    it "gives a projekt without layers the global base layers" do
      global_base = create(:map_layer)

      expect(MapLayer.for_mappable(projekt)).to eq [global_base]
    end

    it "appends the global base layers oldest first, whatever order the database returns them in" do
      older_base = create(:map_layer)
      newer_base = create(:map_layer)
      older_base.update!(name: "Renamed")

      expect(MapLayer.for_mappable(projekt)).to eq [older_base, newer_base]
    end

    it "leaves a projekt with its own base layer alone" do
      own_base = create(:map_layer, mappable: projekt)
      create(:map_layer)

      expect(MapLayer.for_mappable(projekt)).to eq [own_base]
    end

    it "skips the global base layers when told to" do
      overlay = create(:map_layer, :overlay, mappable: projekt)
      create(:map_layer)

      expect(MapLayer.for_mappable(projekt, with_global_base: false)).to eq [overlay]
    end

    it "adds nothing when no global base layer is configured" do
      overlay = create(:map_layer, :overlay, mappable: projekt)

      expect(MapLayer.for_mappable(projekt)).to eq [overlay]
    end

    it "falls back to every global layer for a mappable without layers of its own" do
      global_base = create(:map_layer)
      global_overlay = create(:map_layer, :overlay)

      expect(MapLayer.for_mappable(nil)).to match_array [global_base, global_overlay]
    end
  end
end
