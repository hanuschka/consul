require "rails_helper"

describe "Adm GeoJSON area import on the map tab", type: :request do
  let(:admin) { create(:administrator).user }
  let(:import_controller) { 'data-controller="adm--geojson-area-import"' }

  before do
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("".html_safe)
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("".html_safe)
    login_as(admin)
  end

  %i[proposal_phase budget_phase point_of_interest_phase].each do |factory|
    it "is offered on a #{factory}" do
      get map_adm_projekts_phase_path(create(factory))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(import_controller)
      expect(response.body).to include('data-adm--geojson-area-import-arm-polygon-tool-value="false"')
    end
  end

  it "is not offered on the projekt map tab" do
    get map_adm_projekts_projekt_path(create(:projekt))

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(import_controller)
  end
end
