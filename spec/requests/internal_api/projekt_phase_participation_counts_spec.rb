require "rails_helper"

describe "Participation counts in the internal API", type: :request do
  let(:internal_client) { InternalApiClient.create!(name: "demokratie.today") }
  let(:headers) { { "Authorization" => "Bearer #{internal_client.auth_token}" } }

  def participation_counts(projekt_phase_ids)
    get participation_counts_internal_api_projekt_phases_path,
        params: { projekt_phase_ids: projekt_phase_ids },
        headers: headers

    JSON.parse(response.body)
  end

  def add_voters(poll, count)
    create_list(:user, count).each do |user|
      Poll::Voter.create!(poll: poll, user: user, origin: "web")
    end
  end

  it "refuses a request without a valid token" do
    expect do
      get participation_counts_internal_api_projekt_phases_path, params: { projekt_phase_ids: "1" }
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "counts the comments of comment phases only" do
    comment_phase = create(:projekt_phase, type: "ProjektPhase::CommentPhase")
    proposal_phase = create(:proposal_phase)
    comment_phase.update_columns(comments_count: 7)
    proposal_phase.update_columns(comments_count: 3)

    counts = participation_counts([comment_phase.id, proposal_phase.id].join(","))

    expect(counts["comment"]).to eq(comment_phase.id.to_s => 7)
  end

  it "counts published, accepted and not retired proposals" do
    phase = create(:proposal_phase)
    create_list(:proposal, 2, projekt_phase: phase)
    create(:proposal, projekt_phase: phase, published_at: nil)
    create(:proposal, projekt_phase: phase, admin_accepted: false)
    create(:proposal, projekt_phase: phase).update_columns(retired_at: 1.day.ago)
    create(:proposal, projekt_phase: phase).update_columns(hidden_at: Time.current)

    expect(participation_counts(phase.id.to_s)["proposal"]).to eq(phase.id.to_s => 2)
  end

  it "counts the voters of the best attended published live poll of a phase" do
    phase = create(:voting_phase)
    add_voters(create(:poll, projekt_phase: phase, published: true), 3)
    add_voters(create(:poll, projekt_phase: phase, published: true), 1)
    add_voters(create(:poll, projekt_phase: phase, published: true, live: false), 9)
    add_voters(create(:poll, projekt_phase: phase, published: false), 9)

    expect(participation_counts(phase.id.to_s)["voting"]).to eq(phase.id.to_s => 3)
  end

  it "ranks a budget by its investments and the votes cast on them" do
    budget = create(:budget, :with_heading)
    phase = budget.projekt_phase
    voted_investment = create(:budget_investment, heading: budget.heading)
    voted_investment.update_columns(physical_votes: 4, ballot_lines_count: 2)
    voted_investment.votes_for.create!(voter: create(:user), vote_flag: true, vote_weight: 3)
    voted_investment
      .votes_for
      .create!(voter: create(:user), vote_flag: true, vote_weight: 5)
      .update_columns(conditional: true)
    create(:budget_investment, heading: budget.heading)
    create(:budget_investment, heading: budget.heading).update_columns(hidden_at: Time.current)

    expect(participation_counts(phase.id.to_s)["budget"]).to eq(phase.id.to_s => 11)
  end

  it "answers only for the requested phases" do
    requested_phase = create(:proposal_phase)
    other_phase = create(:proposal_phase)
    create(:proposal, projekt_phase: requested_phase)
    create(:proposal, projekt_phase: other_phase)

    expect(participation_counts(requested_phase.id.to_s)["proposal"]).to eq(requested_phase.id.to_s => 1)
  end

  it "accepts the phase ids as an array" do
    phase = create(:proposal_phase)
    create(:proposal, projekt_phase: phase)

    expect(participation_counts([phase.id.to_s])["proposal"]).to eq(phase.id.to_s => 1)
  end

  it "answers with empty counts for missing or malformed phase ids" do
    create(:proposal, projekt_phase: create(:proposal_phase))

    [nil, "", "abc,", { "a" => "1" }].each do |projekt_phase_ids|
      counts = participation_counts(projekt_phase_ids)

      expect(response).to have_http_status(:ok)
      expect(counts).to eq("comment" => {}, "proposal" => {}, "voting" => {}, "budget" => {})
    end
  end
end
