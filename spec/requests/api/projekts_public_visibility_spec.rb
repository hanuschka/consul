require "rails_helper"
require_relative "../../shared/api_client_helper"

describe "Projekts restricted to a group in the public API", type: :request do
  include ApiClientHelper

  let(:api_client) { create_api_client(access_level: :public_data) }
  let(:headers) { { "Authorization" => "Bearer #{api_client.access_token}" } }
  let!(:open_projekt) { create(:projekt) }
  let!(:restricted_projekt) { create(:projekt) }

  before do
    group = create(:individual_group, kind: "hard")
    group_value = create(:individual_group_value, individual_group: group)
    restricted_projekt.individual_group_values << group_value
  end

  def listed_projekt_ids
    get api_projekts_path, headers: headers

    response.parsed_body.dig("data", "projekts").pluck("id")
  end

  def public_phase_of(projekt, type: "ProjektPhase::EventPhase")
    create(
      :projekt_phase,
      projekt: projekt,
      type: type,
      active: true,
      frontend_visibility: true
    )
  end

  def investment_in(projekt)
    budget_phase = public_phase_of(projekt, type: "ProjektPhase::BudgetPhase")
    budget = create(:budget, :with_heading, projekt_phase: budget_phase)

    create(:budget_investment, heading: budget.heading)
  end

  it "leaves the restricted projekt out of the list" do
    expect(listed_projekt_ids).to include(open_projekt.id)
    expect(listed_projekt_ids).not_to include(restricted_projekt.id)
  end

  it "refuses the restricted projekt" do
    get api_projekt_path(restricted_projekt), headers: headers

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.dig("error", "type")).to eq "forbidden"
  end

  it "serves a projekt without a group restriction" do
    get api_projekt_path(open_projekt), headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "serves a projekt left out of the overview, like the website does" do
    open_projekt.update!(show_in_overview_page: false)

    get api_projekt_path(open_projekt), headers: headers

    expect(response).to have_http_status(:ok)
    expect(listed_projekt_ids).not_to include(open_projekt.id)
  end

  it "leaves events of the restricted projekt out of the list" do
    open_event = create(:projekt_event, projekt_phase: public_phase_of(open_projekt))
    restricted_event = create(:projekt_event, projekt_phase: public_phase_of(restricted_projekt))

    get api_events_path, headers: headers
    listed_event_ids = response.parsed_body.dig("data", "events").pluck("id")

    expect(listed_event_ids).to include(open_event.id)
    expect(listed_event_ids).not_to include(restricted_event.id)

    get api_event_path(restricted_event), headers: headers

    expect(response).to have_http_status(:forbidden)
  end

  it "leaves comments of the restricted projekt out of the list" do
    open_comment = create(:comment, commentable: public_phase_of(open_projekt))
    restricted_comment = create(:comment, commentable: public_phase_of(restricted_projekt))

    get api_comments_path, headers: headers
    listed_comment_ids = response.parsed_body.dig("data", "comments").pluck("id")

    expect(listed_comment_ids).to include(open_comment.id)
    expect(listed_comment_ids).not_to include(restricted_comment.id)
  end

  it "leaves budget investments of the restricted projekt out of the list" do
    open_investment = investment_in(open_projekt)
    restricted_investment = investment_in(restricted_projekt)
    all_investments_path =
      url_for(controller: "/api/budgets/investments", action: :index, only_path: true)

    get all_investments_path, headers: headers
    listed_investment_ids =
      response.parsed_body.dig("data", "budget_investments").pluck("id")

    expect(listed_investment_ids).to include(open_investment.id)
    expect(listed_investment_ids).not_to include(restricted_investment.id)
  end

  context "with a client allowed to read all data" do
    let(:api_client) { create_api_client }

    it "serves the restricted projekt" do
      get api_projekt_path(restricted_projekt), headers: headers

      expect(response).to have_http_status(:ok)
    end
  end
end
