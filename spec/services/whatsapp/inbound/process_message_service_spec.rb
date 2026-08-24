require "rails_helper"

describe Whatsapp::Inbound::ProcessMessageService do
  # A verifying double of the real resource, which is the point: the reaction
  # endpoint is gone from WhatsappApi::Resources::Messages, so any attempt to
  # place one on a citizen's message fails here rather than reaching WhatsApp.
  let(:messages_api) do
    instance_double(WhatsappApi::Resources::Messages, send_typing_indicator: true)
  end

  let(:conversation) do
    double(
      :conversation,
      step: nil,
      last_inbound_at: nil,
      shared_image_id: nil,
      shared_location: nil
    ).tap do |stub|
      allow(stub).to receive(:update!)
      allow(stub).to receive(:hold_offered_confirmations!)
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
    allow(Whatsapp::AiAssistant::RouterService)
      .to receive(:call).and_return(double(:result, success?: true))

    allow(Whatsapp::Inbound::EntryTokenCapture)
      .to receive(:new).and_return(double(:capture, call: nil))
  end

  describe "the waiting feedback a tap gets" do
    let(:raw_message) do
      {
        "interactive" => {
          "button_reply" => { "id" => "menu", "title" => "Hauptmenü" }
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
