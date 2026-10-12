require "rails_helper"
require_relative "../../shared/api_client_helper"

describe "Projekt phases in the public API", type: :request do
  include ApiClientHelper

  let(:api_client) { create_api_client(access_level: :public_data) }
  let(:headers) { { "Authorization" => "Bearer #{api_client.access_token}" } }
  let(:projekt) { create(:projekt) }
  let!(:projekt_phase) do
    projekt.projekt_phases.create!(type: "ProjektPhase::CommentPhase", active: true,
                                   frontend_visibility: true)
  end

  def list_phases
    get api_projekt_projekt_phases_path(projekt), headers: headers
  end

  def show_phase
    get api_projekt_phase_path(projekt_phase), headers: headers
  end

  it "serves the visible phases of a public projekt" do
    list_phases
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "projekt_phases").size).to eq 1

    show_phase
    expect(response).to have_http_status(:ok)
  end

  context "when the projekt is a draft" do
    before { projekt.update!(activated: false) }

    it "refuses its phases" do
      list_phases
      expect(response).to have_http_status(:forbidden)

      show_phase
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "when the projekt is restricted to a group" do
    before do
      group = create(:individual_group, kind: "hard")
      projekt.individual_group_values << create(:individual_group_value, individual_group: group)
    end

    it "refuses its phases" do
      list_phases
      expect(response).to have_http_status(:forbidden)

      show_phase
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with a client allowed to read all data" do
    let(:api_client) { create_api_client }

    before { projekt.update!(activated: false) }

    it "still serves the phases of a draft projekt" do
      list_phases
      expect(response).to have_http_status(:ok)

      show_phase
      expect(response).to have_http_status(:ok)
    end
  end
end
