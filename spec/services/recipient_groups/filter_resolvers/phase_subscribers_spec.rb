require "rails_helper"

describe RecipientGroups::FilterResolvers::PhaseSubscribers do
  let(:projekt) { create(:projekt) }
  let(:phase) { create(:projekt_phase, projekt: projekt) }
  let!(:subscriber) { create(:user, email: "sub@x.test", skip_password_validation: true) }
  let!(:non_subscriber) { create(:user, email: "no@x.test", skip_password_validation: true) }

  before do
    create(:projekt_phase_subscription, user: subscriber, projekt_phase: phase)
  end

  it "returns subscribers of a specific phase" do
    expect(
      described_class.new("projekt_phase_id" => phase.id).emails
    ).to contain_exactly("sub@x.test")
  end

  it "returns all phase subscribers across a projekt" do
    expect(
      described_class.new("projekt_id" => projekt.id).emails
    ).to contain_exactly("sub@x.test")
  end

  it "returns empty when neither id is given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
