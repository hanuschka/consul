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

  describe "hover tooltip of a marked area" do
    let(:tooltip) { "Vom System vorgegeben – nicht verschiebbar" }
    let(:area_path) { "path.leaflet-interactive[stroke='#008000']" }

    it "gives way to the drawing hint on the form map" do
      visit new_proposal_path(projekt_phase_id: projekt_phase.id)

      find(area_path).hover

      expect(page).to have_css(".leaflet-tooltip", text: "Marker")
      expect(page).not_to have_css(".leaflet-tooltip", text: tooltip)
    end

    it "is still shown on a view-only map" do
      proposal = create(:proposal, projekt_phase: projekt_phase)
      create(:map_location, mappable: proposal, latitude: 50.7957, longitude: 7.2045, zoom: 15,
                            features: { "type" => "FeatureCollection", "features" => [{
                              "type" => "Feature", "properties" => {},
                              "geometry" => { "type" => "Point", "coordinates" => [7.2045, 50.7957] }
                            }] })

      visit proposal_path(proposal)

      find(area_path).hover

      expect(page).to have_css(".leaflet-tooltip", text: tooltip)
    end
  end

  context "when the phase only allows entries inside its marked areas" do
    let(:outside_message) { I18n.t("activerecord.errors.messages.map_features_outside_marked_areas") }

    before do
      projekt_phase.settings
                   .find_by!(key: "feature.form.restrict_map_features_to_marked_areas")
                   .update!(value: "active")
    end

    def features_input
      find("[data-features-input-for]", visible: false).value
    end

    def click_map_at(latitude, longitude)
      map = find("[data-map]")
      map.scroll_to(map, align: :center)

      x, y, width, height = page.evaluate_script(<<~JS)
        (function() {
          var element = document.querySelector("[data-map]");
          var point = App.Map.maps[0].map.latLngToContainerPoint([#{latitude}, #{longitude}]);
          var rect = element.getBoundingClientRect();
          return [point.x, point.y, rect.width, rect.height];
        })()
      JS

      page.driver.browser.action
          .move_to(map.native, (x - width / 2).round, (y - height / 2).round)
          .click
          .perform
    end

    it "keeps a pin placed inside a marked area" do
      visit new_proposal_path(projekt_phase_id: projekt_phase.id)

      click_map_at(50.7957, 7.2140)
      expect(page).to have_content(outside_message)

      find("path.leaflet-interactive[stroke='#008000']").click

      expect(page).not_to have_content(outside_message)
      expect(features_input).to include("Point")
    end

    it "removes a pin placed outside the marked areas and says why" do
      visit new_proposal_path(projekt_phase_id: projekt_phase.id)

      click_map_at(50.7957, 7.2140)

      expect(page).to have_content(outside_message)
      expect(features_input).not_to include("Point")
    end
  end
end
