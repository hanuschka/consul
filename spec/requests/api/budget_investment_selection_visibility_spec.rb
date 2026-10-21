require "rails_helper"
require_relative "../../shared/api_client_helper"

describe "Admission in the budget investments API", type: :request do
  include ApiClientHelper

  let(:investment) { create(:budget_investment, feasibility: "feasible", selected: true) }
  let(:budget) { investment.budget }
  let(:public_data_client) { create_api_client(name: "Public data client", access_level: :public_data) }
  let(:admin_client) { create_api_client(name: "Admin client", access_level: :admin) }

  before do
    phases = budget.phases
    phases.update_all(enabled: false)
    phases.where(kind: "valuating").update_all(enabled: true, starts_at: 1.week.ago, ends_at: 1.day.from_now)
    phases.where(kind: "publishing_prices")
          .update_all(enabled: true, starts_at: 1.day.from_now, ends_at: 1.week.from_now)
  end

  def start_price_phase
    budget.phases.where(kind: "valuating").update_all(ends_at: 1.day.ago)
    budget.phases.where(kind: "publishing_prices").update_all(starts_at: 1.day.ago)
  end

  def headers_for(client)
    { "Authorization" => "Bearer #{client.access_token}" }
  end

  def selected_in_show(client)
    get "/api/budget_investments/#{investment.id}", headers: headers_for(client)
    expect(response).to have_http_status(:ok)

    JSON.parse(response.body).dig("data", "budget_investment", "selected")
  end

  def ids_in_index(client, selected:)
    get "/api/budgets/#{budget.id}/investments",
        params: { selected: selected.to_s },
        headers: headers_for(client)
    expect(response).to have_http_status(:ok)

    JSON.parse(response.body).dig("data", "budget_investments").map { |data| data["id"] }
  end

  context "during the valuation phase with the price phase enabled" do
    it "hides the admission from public data clients" do
      expect(selected_in_show(public_data_client)).to be false
      expect(ids_in_index(public_data_client, selected: true)).to be_empty
      expect(ids_in_index(public_data_client, selected: false)).to eq [investment.id]
    end

    it "shows the admission to admin clients" do
      expect(selected_in_show(admin_client)).to be true
      expect(ids_in_index(admin_client, selected: true)).to eq [investment.id]
    end
  end

  it "shows the admission to public data clients once the price phase has started" do
    start_price_phase

    expect(selected_in_show(public_data_client)).to be true
    expect(ids_in_index(public_data_client, selected: true)).to eq [investment.id]
  end
end
