require "rails_helper"

describe "Marked areas on a phase map", type: :system do
  let(:user) { create(:user) }

  let(:marked_area) do
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "properties" => {},
        "geometry" => {
          "type" => "Polygon",
          "coordinates" => [[
            [7.1990, 50.7930], [7.2100, 50.7930], [7.2100, 50.7985],
            [7.1990, 50.7985], [7.1990, 50.7930]
          ]]
        }
      }]
    }
  end

  let(:projekt_phase) do
    create(:proposal_phase, active: true, start_date: 1.day.ago, end_date: 1.day.from_now).tap do |phase|
      phase.projekt.update!(activated: true)
      phase.reload.map_location.update!(latitude: 50.7957, longitude: 7.2045, zoom: 15, features: marked_area)
    end
  end

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before do
    InvisibleCaptcha.timestamp_enabled = false
    login_as(user)
  end

  after { InvisibleCaptcha.timestamp_enabled = true }

  it "places a pin when a marked area is clicked, without opening a popup" do
    visit new_proposal_path(projekt_phase_id: projekt_phase.id)

    find("path.leaflet-interactive[stroke='#008000']").click

    expect(page).not_to have_css(".map-popup-status-message")
    expect(find("[data-features-input-for]", visible: false).value).to include("Point")
  end
end
