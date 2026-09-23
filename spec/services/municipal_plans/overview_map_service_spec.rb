require "rails_helper"

describe MunicipalPlans::OverviewMapService do
  def polygon_features
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "properties" => {},
        "geometry" => {
          "type" => "Polygon",
          "coordinates" => [[[11.58, 50.92], [11.60, 50.92], [11.60, 50.94], [11.58, 50.92]]]
        }
      }]
    }
  end

  def pin_features(longitude = 11.59, latitude = 50.93)
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "properties" => {},
        "geometry" => { "type" => "Point", "coordinates" => [longitude, latitude] }
      }]
    }
  end

  def district_with_area(name)
    district = create(:registered_address_district, name: name)
    create(:map_location, mappable: district, features: polygon_features)
    district
  end

  def district_with_geometry(name, geometry)
    district = create(:registered_address_district, name: name)
    features = { "type" => "FeatureCollection",
                 "features" => [{ "type" => "Feature", "properties" => {}, "geometry" => geometry }] }
    create(:map_location, mappable: district, features: features)
    district
  end

  def plan_in(districts, title:, pinned: true)
    plan = build(:municipal_plan, :published, title: title)
    plan.district_assignments.clear
    districts.each { |district| plan.district_assignments.build(district: district) }
    plan.map_location.features = pinned ? pin_features : {}
    plan.save!
    plan
  end

  def service_for(params)
    districts = RegisteredAddress::District.all.to_a
    scope = MunicipalPlansQuery.new(MunicipalPlan.published, params).call

    MunicipalPlans::OverviewMapService.new(scope, districts: districts,
                                                  selected_district_ids: Array(params[:districts]))
  end

  def marker_titles(service)
    service.markers[:features].map { |feature| feature[:properties][:title] }
  end

  describe "#areas" do
    it "returns one area per Ortsteil that has a polygon, marking the selected ones" do
      lobeda = district_with_area("Lobeda")
      wenigenjena = district_with_area("Wenigenjena")

      areas = service_for(districts: [lobeda.id.to_s]).areas[:features]
      selection = areas.to_h { |area| area[:properties].values_at(:district_id, :selected) }

      expect(selection).to eq(lobeda.id => true, wenigenjena.id => false)
    end

    it "leaves out an Ortsteil without an area, such as Gesamtes Stadtgebiet" do
      district_with_area("Lobeda")
      city_wide = create(:registered_address_district, name: "Gesamtes Stadtgebiet")

      ids = service_for({}).areas[:features].map { |area| area[:properties][:district_id] }

      expect(ids).not_to include(city_wide.id)
    end

    it "keeps the polygon of an Ortsteil delivered as a GeometryCollection with a stray line" do
      polygon = polygon_features["features"].first["geometry"]
      line = { "type" => "MultiLineString", "coordinates" => [[[11.59, 50.91], [11.591, 50.911]]] }
      district_with_geometry("Kernberge", { "type" => "GeometryCollection", "geometries" => [polygon, line] })

      areas = service_for({}).areas[:features]

      expect(areas.map { |area| area[:geometry] }).to eq [polygon]
    end

    it "merges several polygons of a GeometryCollection into one MultiPolygon" do
      polygon = polygon_features["features"].first["geometry"]
      collection = { "type" => "GeometryCollection", "geometries" => [polygon, polygon] }
      district_with_geometry("Kernberge", collection)

      geometry = service_for({}).areas[:features].first[:geometry]

      expect(geometry).to eq("type" => "MultiPolygon", "coordinates" => [polygon["coordinates"]] * 2)
    end

    it "leaves out an Ortsteil whose map location holds only a point" do
      district = create(:registered_address_district, name: "Zwätzen")
      create(:map_location, mappable: district, features: pin_features)

      expect(service_for({}).areas[:features]).to be_empty
    end
  end

  describe "#show?" do
    it "is false on an instance where no Ortsteil areas were loaded" do
      create(:registered_address_district, name: "Lobeda")

      expect(service_for({}).show?).to be false
    end

    it "is true once one Ortsteil has an area" do
      district_with_area("Lobeda")

      expect(service_for({}).show?).to be true
    end
  end

  describe "#markers" do
    it "shows a Vorhaben assigned to four Ortsteile when any one of them is selected" do
      districts = Array.new(4) { |n| district_with_area("Ortsteil #{n}") }
      plan_in(districts, title: "Vier Ortsteile")

      districts.each do |district|
        expect(marker_titles(service_for(districts: [district.id.to_s]))).to eq ["Vier Ortsteile"]
      end
    end

    it "shows no marker for a Vorhaben without a pin" do
      district = district_with_area("Lobeda")
      plan_in([district], title: "Ohne Pin", pinned: false)

      expect(marker_titles(service_for(districts: [district.id.to_s]))).to be_empty
    end

    it "only shows markers of Vorhaben matching the filter" do
      lobeda = district_with_area("Lobeda")
      wenigenjena = district_with_area("Wenigenjena")
      plan_in([lobeda], title: "In Lobeda")
      plan_in([wenigenjena], title: "In Wenigenjena")

      expect(marker_titles(service_for(districts: [lobeda.id.to_s]))).to eq ["In Lobeda"]
    end

    it "works on a full-text search result" do
      district = district_with_area("Lobeda")
      plan_in([district], title: "Eichplatz-Areal")
      plan_in([district], title: "Radweg Saale")
      scope = MunicipalPlan.published.pg_search("Eichplatz")

      service = MunicipalPlans::OverviewMapService.new(scope, districts: [district],
                                                              selected_district_ids: [])

      expect(marker_titles(service)).to eq ["Eichplatz-Areal"]
    end

    it "links each marker to its Vorhaben" do
      district = district_with_area("Lobeda")
      plan = plan_in([district], title: "Eichplatz-Areal")

      marker = service_for({}).markers[:features].first

      expect(marker[:properties][:url]).to eq "/municipal_plans/#{plan.id}"
      expect(marker[:geometry]["coordinates"]).to eq [11.59, 50.93]
    end
  end
end
