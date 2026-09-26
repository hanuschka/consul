require "rails_helper"

describe Whatsapp::AiAssistant::SystemPromptService do
  let(:account) do
    double(:account, user_id: nil, awaiting_link?: false, terms_accepted?: true)
  end

  let(:starting_over) { false }

  let(:projekt_phase) { nil }

  let(:conversation) do
    double(
      :conversation,
      whatsapp_account: account,
      user: nil,
      draft_resource: nil,
      draft_data: nil,
      shared_image_id: nil,
      shared_location: nil,
      projekt_phase: projekt_phase,
      active_proposal_id: nil,
      pending_confirmations: [],
      starting_over?: starting_over
    )
  end

  let(:service) do
    Whatsapp::AiAssistant::SystemPromptService.new(conversation: conversation)
  end

  let(:state) { service.send(:state_section) }

  before do
    allow(Whatsapp::EligiblePhasesQuery).to receive(:uncapped).and_return([])
    allow(Whatsapp::AiAssistant::DialogDigest)
      .to receive(:new).and_return(double(:digest, transcript: nil))
  end

  # The phase line reading "none" is not the same statement as "the projekt you
  # were just in is over with": a conversation that never had one says exactly the
  # same thing, and the replayed history still has the projekt all through it. So
  # the reset is said as well as done, and only on the turn it happened.
  describe "the line that says the citizen asked to start over" do
    context "when they just asked" do
      let(:starting_over) { true }

      it "says nothing is selected any more" do
        expect(state).to include("nothing is selected any more")
      end

      it "says the projekt named earlier no longer applies" do
        expect(state).to include("no projekt named earlier in this conversation applies")
      end
    end

    context "on any other turn" do
      it "is absent" do
        expect(state).not_to include("asked to start over")
      end
    end
  end
end
