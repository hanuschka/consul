require "rails_helper"

describe Whatsapp::AiAssistant::SystemPromptService do
  let(:account) do
    double(:account, user_id: nil, awaiting_link?: false, terms_accepted?: true)
  end

  let(:starting_over) { false }

  let(:projekt_phase) { nil }

  let(:unsaved_work) { false }

  let(:parked_projekt_phase) { nil }

  let(:parked_text) { nil }

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
      starting_over?: starting_over,
      unsaved_submission?: false,
      draft_picture_attached?: false,
      image_question_available?: false,
      last_draft_at: nil,
      pending_open_question_id: nil,
      proposed_location: nil,
      resumed_poll_question_ids: [],
      subject_changed_at: nil,
      typing_hint_due?: false,
      unsaved_work?: unsaved_work,
      replayable_turn?: false,
      awaiting_link?: false,
      comment_invited?: false,
      revision_kind: nil,
      revision_open?: false,
      pending_comment: nil,
      parked_projekt_phase: parked_projekt_phase,
      parked_submission_text: parked_text
    )
  end

  let(:service) do
    Whatsapp::AiAssistant::SystemPromptService.new(conversation: conversation)
  end

  let(:state) { service.send(:state_section) }

  before do
    allow(Whatsapp::EligiblePhasesQuery).to receive(:uncapped).and_return([])
    allow(Whatsapp::Polls::OwedQuestionQuery).to receive(:for).and_return(nil)
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

  # Kept over the question whether to discard what was open, so the citizen who
  # chose to keep it is offered the new one once it is done.
  describe "the line naming a contribution asked for while another was open" do
    let(:other_projekt) { double(:projekt) }

    let(:other_phase) { double(:projekt_phase, id: 42, projekt: other_projekt) }

    before do
      allow(Whatsapp::ProjektLink).to receive(:title).with(other_projekt).and_return("Jugendbeteiligung")
    end

    context "while the other is still open" do
      let(:parked_projekt_phase) { other_phase }

      let(:parked_text) { "Trinkbrunnen am Skaterpark" }

      let(:unsaved_work) { true }

      it "names the projekt, the phase and their words" do
        expect(state).to include(
          "- Also asked for: a contribution to Jugendbeteiligung (projekt_phase_id 42), " \
          "written as: \"Trinkbrunnen am Skaterpark\""
        )
      end

      it "holds it back until the open one is done" do
        expect(state).to include("It waits until what is open now is published or discarded")
      end
    end

    context "once nothing else is open" do
      let(:parked_projekt_phase) { other_phase }

      it "offers to carry on with it" do
        expect(state).to include("Nothing else is open, so offer to carry on with it")
      end

      it "leaves out words the citizen never wrote" do
        expect(state).not_to include("written as")
      end
    end

    context "with nothing asked for" do
      it "is absent" do
        expect(state).not_to include("Also asked for")
      end
    end
  end
end
