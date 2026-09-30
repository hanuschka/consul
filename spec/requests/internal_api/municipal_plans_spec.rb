require "rails_helper"

describe "Vorhaben in the internal API", type: :request do
  let(:internal_client) { InternalApiClient.create!(name: "demokratie.today") }
  let(:headers) { { "Authorization" => "Bearer #{internal_client.auth_token}" } }

  before { Setting["process.municipal_plans"] = true }

  def listed_ids(params = {})
    get internal_api_municipal_plans_path, params: params, headers: headers
    JSON.parse(response.body)["municipal_plans"].map { |plan| plan["id"] }
  end

  it "lists only published Vorhaben with the fields of the public API" do
    published = create(:municipal_plan, :published)
    create(:municipal_plan)
    create(:municipal_plan, status: "archived")

    get internal_api_municipal_plans_path, headers: headers
    plans = JSON.parse(response.body)["municipal_plans"]

    expect(plans.map { |plan| plan["id"] }).to eq([published.id])
    expect(plans.first).to eq(JSON.parse(MunicipalPlanSerializer.new(published.reload).serialize.to_json))
  end

  it "paginates when asked to" do
    create_list(:municipal_plan, 3, :published)

    get internal_api_municipal_plans_path, params: { page: 2, per_page: 2 }, headers: headers
    body = JSON.parse(response.body)

    expect(body["municipal_plans"].size).to eq(1)
    expect(body["pagination"])
      .to include("page" => 2, "per_page" => 2, "total_count" => 3, "total_pages" => 2)
  end

  it "includes archived Vorhaben for changed_since" do
    plan = create(:municipal_plan, :published, released_at: 1.month.ago)
    plan.update!(status: "archived")

    expect(listed_ids(changed_since: Date.current.iso8601)).to eq([plan.id])
  end

  it "returns not found for a draft or an archived Vorhaben" do
    [create(:municipal_plan), create(:municipal_plan, status: "archived")].each do |hidden|
      get internal_api_municipal_plan_path(hidden), headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  it "never includes internal notes" do
    plan = create(:municipal_plan, :published)
    plan.memos.create!(user: create(:user), text: "Interner Vermerk")

    get internal_api_municipal_plan_path(plan), headers: headers

    expect(response.body).not_to include("Interner Vermerk")
  end

  it "returns no data with the module switched off" do
    Setting["process.municipal_plans"] = false
    plan = create(:municipal_plan, :published)

    [internal_api_municipal_plans_path, internal_api_municipal_plan_path(plan)].each do |path|
      get path, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
