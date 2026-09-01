require "rails_helper"

describe RecipientGroups::FilterResolvers::VotingParticipants do
  # VotingPhase auto-creates a Poll via after_create callback.
  # Participation is tracked via Poll::Voter (not ActsAsVotable::Vote).
  # Must use projekt.projekt_phases.create! to get proper STI subclass instance.
  let(:projekt) { create(:projekt) }
  let(:phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase") }
  let!(:voter) { create(:user, :verified, email: "v@x.test", skip_password_validation: true) }
  let!(:non_voter) { create(:user, email: "n@x.test", skip_password_validation: true) }

  before do
    poll = Poll.find_by(projekt_phase_id: phase.id)
    Poll::Voter.create!(user: voter, poll: poll, origin: "web")
  end

  it "returns users who voted on polls in this voting phase" do
    expect(
      described_class.new("projekt_phase_id" => phase.id).emails
    ).to contain_exactly("v@x.test")
  end

  it "returns empty when phase_id is missing" do
    expect(described_class.new({}).emails).to eq([])
  end
end
