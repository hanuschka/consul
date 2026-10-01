require "rails_helper"

describe Whatsapp::Inbound::ProcessMessageService do
  # A verifying double of the real resource, which is the point: the reaction
  # endpoint is gone from WhatsappApi::Resources::Messages, so any attempt to
  # place one on a citizen's message fails here rather than reaching WhatsApp.
  let(:messages_api) do
    instance_double(
      WhatsappApi::Resources::Messages,
      send_typing_indicator: double(:response, success?: true)
    )
  end

  let(:unsaved_submission) { false }

  let(:conversation) do
    double(
      :conversation,
      step: nil,
      last_inbound_at: nil,
      shared_image_id: nil,
      shared_location: nil,
      unsaved_submission?: unsaved_submission,
      active_poll_id: nil,
      pending_map_question_id: nil,
      pending_comment: nil,
      pending_poll_id: nil,
      step_in_progress?: false
    ).tap do |stub|
      allow(stub).to receive(:update!)
      allow(stub).to receive(:hold_offered_confirmations!)
      allow(stub).to receive(:hold_stop_question!)
      allow(stub).to receive(:clear_stop_question!)
      allow(stub).to receive(:begin_start_over!)
      allow(stub).to receive(:discard_draft!)
      allow(stub).to receive(:clear_retry_inbound!)
    end
  end

  let(:account) do
    double(:account, conversation: conversation, opt_out_at: nil, ai_disclosed?: true)
  end

  let(:whatsapp_message) do
    double(
      :whatsapp_message,
      whatsapp_account: account,
      wa_message_id: "wamid.INBOUND",
      sent_at: Time.current,
      audio?: false,
      welcome?: false,
      body: body
    )
  end

  let(:body) { nil }

  let(:routed_notes) { [] }

  def tap_of(id:, title:)
    {
      "interactive" => {
        "button_reply" => { "id" => id, "title" => title }
      }
    }
  end

  def process(raw_message)
    Whatsapp::Inbound::ProcessMessageService
      .new(whatsapp_message: whatsapp_message, raw_message: raw_message).call
  end

  before do
    allow(WhatsappApi::Client)
      .to receive(:new).and_return(double(:client, messages: messages_api))

    allow(Whatsapp).to receive(:enabled?).and_return(true)
    allow(Ai::Settings).to receive(:ai_available?).and_return(true)

    allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record)

    # Captured rather than merely counted: for the taps below the whole question is
    # what the assistant was told, and the note is the only place it is said.
    allow(Whatsapp::AiAssistant::RouterService).to receive(:call) do |**arguments|
      routed_notes << arguments[:inbound_text]

      double(:result, success?: true)
    end

    allow(Whatsapp::Inbound::EntryTokenCapture)
      .to receive(:new).and_return(double(:capture, call: nil))
  end

  describe "the waiting feedback a tap gets" do
    let(:raw_message) do
      {
        "interactive" => {
          "button_reply" => { "id" => "menu", "title" => "Von vorne loslegen" }
        }
      }
    end

    before do
      allow(Whatsapp::Send).to receive(:recovery_action_from).and_return(nil)
      allow(Whatsapp::FlowActions).to receive(:parse).and_return(action: :menu, param: nil)
    end

    it "shows the typing indicator on the tapped message" do
      process(raw_message)

      expect(messages_api)
        .to have_received(:send_typing_indicator).with(message_id: "wamid.INBOUND")
    end

    # The regression this ticket exists for: the hourglass was a POST to /messages
    # sent immediately after the indicator, and any message send dismisses the
    # bubble — so the mark meant to stand in for the dots was removing them.
    it "places no reaction on the citizen's own message" do
      process(raw_message)

      expect(messages_api).to have_received(:send_typing_indicator).once
    end

    it "asks the assistant by the same path a typed message takes" do
      process(raw_message)

      expect(Whatsapp::AiAssistant::RouterService).to have_received(:call).once
    end
  end

  describe "the waiting feedback a typed message gets" do
    let(:body) { "Was läuft grade?" }

    it "is the same indicator on the same message" do
      process({})

      expect(messages_api)
        .to have_received(:send_typing_indicator).with(message_id: "wamid.INBOUND").once
    end
  end

  # The bug: tapping the way out of a projekt left the projekt exactly where it
  # was, so the state block still named it and the next reply offered a
  # contribution to it in the same breath as saying they were back at the start.
  describe "the pills that mean back to the beginning" do
    let(:main_menu_tap) do
      tap_of(id: Whatsapp::FlowActions.id_for(action: :main_menu), title: "Von vorne loslegen")
    end

    let(:help_tap) do
      tap_of(id: Whatsapp::Send::RECOVERY_ACTION_IDS.fetch(:help), title: "Hilfe")
    end

    # What the reset clears is the conversation's own business
    # (Whatsapp::Conversation#begin_start_over!), shared with the typed request.
    it "starts over on a main-menu tap" do
      process(main_menu_tap)

      expect(conversation).to have_received(:begin_start_over!)
    end

    it "starts over on the help pill offered under a cancellation" do
      process(help_tap)

      expect(conversation).to have_received(:begin_start_over!)
    end

    # The reset is half of it. The other half is that the replayed history still
    # has the projekt in it, so the newest message has to say it no longer counts.
    it "tells the assistant nothing is selected any more" do
      process(main_menu_tap)

      expect(routed_notes.last).to include("No projekt and no phase is selected any more")
    end

    it "asks for the overview rather than naming the projekt they left" do
      process(main_menu_tap)

      expect(routed_notes.last).to include("what is open to take part in")
    end

    it "records it, because a citizen escaping a reply is worth counting" do
      process(main_menu_tap)

      expect(Whatsapp::AiAssistant::DecisionLog)
        .to have_received(:record).with(hash_including(event: :start_over))
    end

    # The gate that does not halt: the citizen is owed the overview, and that is
    # the assistant's to write.
    it "still asks the assistant" do
      process(main_menu_tap)

      expect(Whatsapp::AiAssistant::RouterService).to have_received(:call).once
    end

    it "keeps everything the phase is not" do
      process(main_menu_tap)

      expect(conversation).not_to have_received(:discard_draft!)
    end

    context "when a contribution is half-written" do
      let(:unsaved_submission) { true }

      # This pill is on every message the bot sends, so a tap on it may not be
      # what throws away text the citizen spent ten minutes writing.
      it "discards nothing" do
        process(main_menu_tap)

        expect(conversation).not_to have_received(:discard_draft!)
      end

      it "asks before anything is discarded" do
        process(main_menu_tap)

        expect(routed_notes.last).to include("Nothing has been discarded")
      end

      it "still starts over, so the reply knows what was asked for" do
        process(main_menu_tap)

        expect(conversation).to have_received(:begin_start_over!)
      end
    end
  end

  # Unchanged, and asserted so: cancelling already discarded the draft and the
  # phase with it, and it halts where the start-over gate deliberately does not.
  describe "the cancel pill" do
    let(:cancel_tap) do
      tap_of(id: Whatsapp::Send::RECOVERY_ACTION_IDS.fetch(:cancel), title: "Abbrechen")
    end

    before do
      allow(Whatsapp::Send).to receive(:recovery)
    end

    it "discards the draft" do
      process(cancel_tap)

      expect(conversation).to have_received(:discard_draft!)
    end

    it "has the assistant say what was discarded" do
      process(cancel_tap)

      expect(Whatsapp::AiAssistant::RouterService).to have_received(:call).once
      expect(routed_notes.last).to include(Whatsapp::DiscardNotes::NOTHING)
    end

    it "discards and answers with the fixed line where no assistant is available" do
      allow(Ai::Settings).to receive(:ai_available?).and_return(false)

      process(cancel_tap)

      expect(conversation).to have_received(:discard_draft!)
      expect(Whatsapp::AiAssistant::RouterService).not_to have_received(:call)
      expect(Whatsapp::Send).to have_received(:recovery)
    end
  end

  # The state pills under a reply about one proposal (Whatsapp::StatePills): the tap
  # names the proposal, so it is answered for that proposal rather than for whichever
  # one the model remembers.
  describe "the comment pill" do
    let(:user) { double(:user) }
    let(:proposal) { double(:proposal, id: 482, title: "Mehr Bänke") }
    let(:refusal) { nil }
    let(:comment_tap) do
      tap_of(
        id: Whatsapp::FlowActions.id_for(action: :comment_start, param: 482),
        title: "Kommentieren"
      )
    end

    before do
      allow(account).to receive(:user).and_return(user)
      allow(Proposal).to receive_message_chain(:not_retired, :find_by)
        .with(id: 482).and_return(proposal)
      allow(Whatsapp::Contributions::CreateCommentService)
        .to receive(:thread_refusal).with(proposal: proposal, user: user).and_return(refusal)
      allow(conversation).to receive(:store_comment_proposal_id!)
      allow(conversation).to receive(:open_step!)
    end

    it "opens the comment on the proposal the pill names" do
      process(comment_tap)

      expect(conversation).to have_received(:store_comment_proposal_id!).with(482)
      expect(conversation).to have_received(:open_step!).with("comment")
    end

    it "asks the assistant for the comment on that proposal" do
      process(comment_tap)

      expect(routed_notes.last).to include("proposal 482", "draft_comment")
    end

    context "when comments have closed since the pill was sent" do
      let(:refusal) { :closed }

      it "opens nothing and has the assistant say so" do
        process(comment_tap)

        expect(conversation).not_to have_received(:open_step!)
        expect(routed_notes.last).to include("comments on that contribution have closed")
      end
    end
  end

  describe "the follow pill" do
    let(:user) { double(:user) }
    let(:projekt) { double(:projekt, id: 45) }

    def follow_tap(action)
      tap_of(id: Whatsapp::FlowActions.id_for(action: action, param: 45), title: "Folgen")
    end

    before do
      allow(account).to receive(:user).and_return(user)
      allow(Projekt).to receive_message_chain(:activated, :find_by)
        .with(id: 45).and_return(projekt)
      allow(Whatsapp::ProjektLink).to receive(:title).with(projekt).and_return("Radweg")
      allow(Whatsapp::Subscriptions).to receive(:follow)
      allow(Whatsapp::Subscriptions).to receive(:unfollow)
      allow(conversation).to receive(:note_completed_tool_result!)
    end

    after { Current.reset }

    it "follows the projekt the pill names" do
      process(follow_tap(:follow_enable))

      expect(Whatsapp::Subscriptions).to have_received(:follow).with(user: user, projekt: projekt)
      expect(routed_notes.last).to include("now follows \"Radweg\"")
    end

    it "stops following it from the other face of the pill" do
      process(follow_tap(:follow_disable))

      expect(Whatsapp::Subscriptions)
        .to have_received(:unfollow).with(user: user, projekt: projekt)
      expect(routed_notes.last).to include("no longer follows \"Radweg\"")
    end

    it "keeps the projekt in focus, so the reply carries the pill that undoes it" do
      process(follow_tap(:follow_enable))

      expect(Current.whatsapp_pill_focus).to eq(projekt_id: 45)
    end

    context "with an unlinked number" do
      let(:user) { nil }

      it "follows nothing and asks for an account" do
        process(follow_tap(:follow_enable))

        expect(Whatsapp::Subscriptions).not_to have_received(:follow)
        expect(routed_notes.last).to include("not linked to an account")
      end
    end
  end

  # Structural rather than behavioural, and deliberately so: the reaction
  # capability was removed rather than merely left uncalled, and this is what
  # notices it being reintroduced.
  describe "the reaction capability" do
    it "no longer exists on the message resource" do
      expect(WhatsappApi::Resources::Messages.instance_methods).not_to include(:send_reaction)
    end

    it "no longer exists on Whatsapp::Send" do
      expect(Whatsapp::Send).not_to respond_to(:acknowledge_tap)
      expect(Whatsapp::Send).not_to respond_to(:withdraw_tap_acknowledgement)
      expect(Whatsapp::Send).not_to respond_to(:react)
    end
  end
end
