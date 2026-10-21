require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::SendProjektCard do
  # A citizen who asked to submit something and then picked a projekt that takes a
  # submission in one phase only gets that submission opened rather than a card
  # repeating the question they had just answered.
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::SendProjektCard.new(
      conversation: conversation, citizen_words: "das Mobilitätsprojekt"
    )
  end

  let(:projekt) { double(:projekt) }
  let(:projekt_phase) { double(:projekt_phase, id: 42) }
  let(:account) { double(:account, user: double(:user)) }
  let(:submission_wished) { true }
  let(:eligible) { true }
  let(:submission_row) do
    { id: Whatsapp::FlowActions.id_for(action: :idea_start, param: 42), title: "Vorschlag erstellen" }
  end
  let(:submission_rows) { [submission_row] }
  let(:start_draft) { double(:start_draft, call: { started: true, projekt: "Mobilität" }) }

  let(:conversation) do
    double(
      :conversation,
      unshown_preview_kind: nil,
      user: account.user,
      whatsapp_account: account,
      submission_wished?: submission_wished,
      unsaved_work?: false,
      active_poll_id: nil,
      typing_hint_due?: false
    ).tap do |stub|
      allow(stub).to receive(:clear_submission_wish!)
    end
  end

  def send_card
    tool.execute(projekt_name: "Mobilität", summary: "Worum es geht.")
  end

  before do
    allow(Whatsapp::ProjektByNameQuery).to receive(:readable).and_return(projekt)
    allow(Whatsapp::ProjektCardActions).to receive(:call).and_return(submission_rows + [{ id: "other" }])
    allow(Whatsapp::ProjektCardActions).to receive(:submission_entries).and_return(submission_rows)
    allow(Whatsapp::ProjektCardActions).to receive(:buttons) { |actions| actions }
    allow(Whatsapp::ProjektCardActions).to receive(:more_votes?).and_return(false)
    allow(Whatsapp::ProjektLink).to receive(:title).and_return("Mobilität")
    allow(Whatsapp::ProjektLink).to receive(:url).and_return("https://example.org/mobilitaet")
    allow(Whatsapp::ProjektCard).to receive(:image_url).and_return(nil)
    allow(Whatsapp::EligiblePhasesQuery).to receive(:uncapped).and_return([])
    allow(Whatsapp::Send).to receive(:buttons_with_picture)
    allow(ProjektPhase).to receive_message_chain(:includes, :find_by).and_return(projekt_phase)
    allow(Whatsapp::EligiblePhasesQuery).to receive(:eligible?).with(projekt_phase).and_return(eligible)
    allow(Ai::Tools::WhatsappAiAssistant::StartDraft).to receive(:new).and_return(start_draft)
  end

  context "when the wished-for submission goes to one phase" do
    it "opens the submission there instead of sending the card" do
      answer = send_card

      expect(start_draft).to have_received(:call).with(projekt_phase_id: "42")
      expect(Whatsapp::Send).not_to have_received(:buttons_with_picture)
      expect(answer).to include(started: true, card_sent: false)
    end

    # The words they picked the projekt with are not their idea, and StartDraft
    # parks whatever it is given as the idea held over an unsaved-work question.
    it "leaves out the words the projekt was picked with" do
      send_card

      expect(Ai::Tools::WhatsappAiAssistant::StartDraft)
        .to have_received(:new).with(conversation: conversation, citizen_words: nil)
    end

    it "clears the wish" do
      send_card

      expect(conversation).to have_received(:clear_submission_wish!)
    end

    it "leaves the conversation waiting for the idea" do
      send_card

      expect(tool.diagnostic_step).to eq(Whatsapp::Conversation::Step::AWAITING_IDEA)
    end

    context "while other work is unsaved" do
      let(:work_in_progress) { { error: "The citizen is part-way through a comment", hint: "Ask" } }
      let(:start_draft) { double(:start_draft, call: work_in_progress) }

      it "answers with the question about the other work and sends no card" do
        expect(send_card).to eq(work_in_progress)
        expect(Whatsapp::Send).not_to have_received(:buttons_with_picture)
      end

      it "clears the wish all the same" do
        send_card

        expect(conversation).to have_received(:clear_submission_wish!)
      end

      it "does not report the conversation as waiting for the idea" do
        send_card

        expect(tool.diagnostic_step).to be_nil
      end
    end

    context "where the chat cannot take a submission into that phase" do
      let(:eligible) { false }

      it "sends the card with the way to submit instead" do
        send_card

        expect(Ai::Tools::WhatsappAiAssistant::StartDraft).not_to have_received(:new)
        expect(Whatsapp::Send).to have_received(:buttons_with_picture)
          .with(hash_including(buttons: submission_rows))
      end
    end
  end

  context "when the wished-for submission can go to several phases" do
    let(:submission_rows) { [submission_row, submission_row.merge(id: "whatsapp_flow_idea_start-43")] }

    it "sends the card offering only the ways to submit" do
      send_card

      expect(Ai::Tools::WhatsappAiAssistant::StartDraft).not_to have_received(:new)
      expect(Whatsapp::Send).to have_received(:buttons_with_picture)
        .with(hash_including(buttons: submission_rows))
    end
  end

  context "without a wish to submit" do
    let(:submission_wished) { false }

    it "sends the whole card and opens nothing" do
      send_card

      expect(Ai::Tools::WhatsappAiAssistant::StartDraft).not_to have_received(:new)
      expect(Whatsapp::Send).to have_received(:buttons_with_picture)
      expect(tool.diagnostic_step).to be_nil
    end
  end
end
