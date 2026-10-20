require "rails_helper"

describe "Adm phase marked-areas setting", type: :request do
  let(:admin) { create(:administrator).user }
  let(:hint) { I18n.t("adm.projekts.phases.general_settings.no_marked_areas") }
  let(:label) { I18n.t("projekt_phase_setting.proposal_phase.feature.form.restrict_map_features_to_marked_areas") }

  let(:area) do
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "properties" => {},
        "geometry" => {
          "type" => "Polygon",
          "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]]
        }
      }]
    }
  end

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  %i[proposal_phase budget_phase point_of_interest_phase].each do |factory|
    it "shows the no-areas hint on a #{factory} without areas" do
      phase = create(factory)

      get general_settings_adm_projekts_phase_path(phase)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(hint))
    end
  end

  it "shows the toggle label on the proposal phase" do
    get general_settings_adm_projekts_phase_path(create(:proposal_phase))

    expect(response.body).to include(CGI.escapeHTML(label))
  end

  it "hides the hint once areas are drawn on the phase map" do
    phase = create(:proposal_phase)
    phase.reload.map_location.update!(features: area)

    get general_settings_adm_projekts_phase_path(phase)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(CGI.escapeHTML(hint))
  end
end
