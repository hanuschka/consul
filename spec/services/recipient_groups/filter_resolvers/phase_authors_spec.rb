require "rails_helper"

describe RecipientGroups::FilterResolvers::PhaseAuthors do
  describe "BudgetPhase" do
    let(:phase) { create(:projekt_phase, :budget_phase) }
    let!(:winner_author) { create(:user, email: "win@x.test", skip_password_validation: true) }

    before do
      allow(phase).to receive(:authors_of_winners_ids).and_return([winner_author.id])
      allow(ProjektPhase).to receive(:find_by).with(id: phase.id).and_return(phase)
    end

    it "returns authors for criterion=winners" do
      emails = described_class.new("projekt_phase_id" => phase.id, "criterion" => "winners").emails
      expect(emails).to contain_exactly("win@x.test")
    end
  end

  describe "ProposalPhase" do
    let(:phase) { create(:projekt_phase, :proposal_phase) }
    let!(:author) { create(:user, email: "p@x.test", skip_password_validation: true) }

    before do
      Proposal.create!(
        title: "Test Proposal",
        summary: "Summary",
        description: "Description",
        responsible_name: "Test",
        resource_terms: "1",
        published_at: Time.current,
        projekt_phase: phase,
        author: author
      )
    end

    it "returns all proposal authors for criterion=all" do
      emails = described_class.new("projekt_phase_id" => phase.id, "criterion" => "all").emails
      expect(emails).to contain_exactly("p@x.test")
    end
  end

  it "returns empty when projekt_phase_id is missing" do
    expect(described_class.new({}).emails).to eq([])
  end
end
