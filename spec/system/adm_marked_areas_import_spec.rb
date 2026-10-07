require "rails_helper"

describe "Importing marked areas on the phase map tab", type: :system do
  let(:admin) { create(:administrator).user }
  let(:phase) { create(:proposal_phase) }
  let(:file) { Rails.root.join("spec/fixtures/files/marked_areas.geojson") }

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before do
    phase.reload.map_location.update!(
      latitude: 50.7957, longitude: 7.2045, zoom: 15,
      features: { "type" => "FeatureCollection", "features" => [{
        "type" => "Feature", "properties" => {},
        "geometry" => { "type" => "Point", "coordinates" => [7.30, 50.83] }
      }] }
    )
    login_as(admin)
  end

  def features_input
    JSON.parse(find("[data-map-target='features']", visible: false).value)
  end

  it "replaces the phase map with the file's areas, which then allow entries in any of them" do
    visit map_adm_projekts_phase_path(phase)

    find("input[type=file][data-adm--geojson-area-import-target='file']").set(file)

    expect(page).to have_content(I18n.t("components.adm.map_setting_component.geojson_import.messages.imported"))
    expect(features_input["features"].map { |feature| feature.dig("geometry", "type") }).to eq %w[Polygon Polygon]

    find("[data-map-target='features']", visible: false)
      .ancestor("form")
      .find("[type=submit]")
      .click

    expect(page).to have_css(".input-success-message")

    saved_types = phase.reload.map_location.to_geo_json["features"].map { |feature| feature.dig("geometry", "type") }
    boundary = phase.map_boundary

    expect(saved_types).to eq %w[Polygon Polygon]
    expect(boundary.contains?(50.797, 7.204)).to be true
    expect(boundary.contains?(50.794, 7.204)).to be true
    expect(boundary.contains?(50.7952, 7.204)).to be false
  end
end
