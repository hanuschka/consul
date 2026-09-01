require "rails_helper"

# Smoke test for the spec suite itself. It does not assert product behaviour;
# it checks that the pieces every other spec depends on are in working order:
# the test database, the seeded settings and the core factories.
describe "Spec suite smoke test" do
  it "has loaded the seeds into the test database" do
    expect(Setting.count).to be > 0
  end

  it "builds a user with the core factory" do
    user = create(:user)

    expect(user).to be_persisted
    expect(user.email).to be_present
  end

  it "builds a projekt with a phase and a resource hanging off it" do
    proposal = create(:proposal)

    expect(proposal).to be_persisted
    expect(proposal.projekt_phase).to be_present
    expect(proposal.projekt).to be_present
  end

  # shoulda-matchers only mixes its ActiveRecord matchers into example groups
  # typed :model. Specs under spec/models get that type inferred from their
  # location; anywhere else it has to be passed explicitly, as it is here.
  describe Proposal, type: :model do
    it { is_expected.to belong_to(:projekt_phase) }
    it { is_expected.to validate_presence_of(:projekt_phase) }
  end
end
