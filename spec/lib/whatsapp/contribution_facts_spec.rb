require "rails_helper"

describe Whatsapp::ContributionFacts do
  # The citizen's own proposal reads as not supportable rather than as one they
  # have not supported yet, so the model never offers its author a support.
  let(:user) { build_stubbed(:user) }
  let(:author) { build_stubbed(:user) }
  let(:proposal) { build_stubbed(:proposal, author: author) }
  let(:supported) { false }

  before do
    allow(proposal).to receive(:projekt_phase).and_return(nil)
    allow(proposal).to receive(:voted_up_by?).with(user).and_return(supported)
  end

  def facts
    Whatsapp::ContributionFacts.call(proposal, user: user)
  end

  it "offers someone else's proposal for support" do
    expect(facts).to include(
      written_by_you: false,
      supported_by_you: false,
      supportable: true,
      support_action_id: "support_toggle-#{proposal.id}"
    )
  end

  describe "for the citizen's own proposal" do
    let(:author) { user }

    it "leaves out the support and that they do not support it" do
      expect(facts).to include(written_by_you: true, supportable: false)
      expect(facts).not_to include(:supported_by_you, :support_action_id)
    end

    describe "that they supported on the page before" do
      let(:supported) { true }

      it "keeps the support and the way to take it back" do
        expect(facts).to include(
          written_by_you: true,
          supported_by_you: true,
          supportable: true,
          support_action_id: "support_toggle-#{proposal.id}"
        )
      end
    end
  end
end
