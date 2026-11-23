require "rails_helper"

describe "WhatsApp queries and projekts restricted to a group" do
  let!(:open_projekt) { create(:projekt) }
  let!(:restricted_projekt) { create(:projekt) }

  before do
    open_projekt.page.update!(status: "published")
    restricted_projekt.page.update!(status: "published")

    group = create(:individual_group, kind: "hard")
    group_value = create(:individual_group_value, individual_group: group)
    restricted_projekt.individual_group_values << group_value
    Projekt.reset_visible_projekt_ids
  end

  def listed_proposal_in(projekt)
    create(
      :proposal,
      projekt_phase: create(:projekt_phase, projekt: projekt),
      admin_accepted: true
    )
  end

  it "does not count the restricted projekt as visible" do
    expect(Whatsapp::EligiblePhasesQuery.projekt_visible?(open_projekt)).to be true
    expect(Whatsapp::EligiblePhasesQuery.projekt_visible?(restricted_projekt)).to be false
  end

  it "leaves the restricted projekt's phases out of the public phases" do
    open_phase = create(:projekt_phase, projekt: open_projekt)
    restricted_phase = create(:projekt_phase, projekt: restricted_projekt)

    expect(ProjektPhase.of_publicly_visible_projekt).to include(open_phase)
    expect(ProjektPhase.of_publicly_visible_projekt).not_to include(restricted_phase)
  end

  it "does not resolve the restricted projekt by name" do
    readable_candidates = Whatsapp::ProjektByNameQuery.readable_candidates

    expect(readable_candidates).to include(open_projekt)
    expect(readable_candidates).not_to include(restricted_projekt)
  end

  it "keeps proposals of the restricted projekt out of reach" do
    open_proposal = listed_proposal_in(open_projekt)
    restricted_proposal = listed_proposal_in(restricted_projekt)

    expect(Whatsapp::ReachableContributionsQuery.listed_proposal?(open_proposal)).to be true
    expect(Whatsapp::ReachableContributionsQuery.listed_proposal?(restricted_proposal)).to be false
  end

  it "does not announce the restricted projekt" do
    expect(open_projekt.announceable_on_whatsapp?).to be true
    expect(restricted_projekt.announceable_on_whatsapp?).to be false
  end

  it "lists only open projekts as followed, but lets either be unfollowed" do
    user = create(:user)
    ProjektSubscription.create!(user: user, projekt: open_projekt, active: true)
    ProjektSubscription.create!(user: user, projekt: restricted_projekt, active: true)

    listed = Whatsapp::FollowedProjektsQuery.new(user: user).call
    unfollowable = Whatsapp::FollowedProjektsQuery.uncapped(user: user)

    expect(listed).to eq [open_projekt]
    expect(unfollowable).to contain_exactly(open_projekt, restricted_projekt)
  end
end
