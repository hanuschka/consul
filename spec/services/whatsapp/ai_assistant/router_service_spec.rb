require "rails_helper"

describe Whatsapp::AiAssistant::RouterService do
  let(:messages_api) do
    instance_double(WhatsappApi::Resources::Messages, send_typing_indicator: true)
  end

  let(:conversation) { double(:conversation, step: nil) }

  let(:service) do
    Whatsapp::AiAssistant::RouterService.new(
      conversation: conversation,
      inbound_text: "The citizen tapped the button \"Hauptmenü\" (action menu).",
      inbound_message_id: inbound_message_id
    )
  end

  let(:inbound_message_id) { "wamid.INBOUND" }

  before do
    allow(WhatsappApi::Client)
      .to receive(:new).and_return(double(:client, messages: messages_api))

    allow(Whatsapp::AiAssistant::DecisionLog).to receive(:record)
  end

  # WhatsApp dismisses the bubble when a message is sent and again after
  # TYPING_INDICATOR_SECONDS, and both happen inside the tool loop — so the turn
  # asks for it again on every call it makes rather than going quiet halfway.
  describe "keeping the waiting feedback visible through a turn" do
    it "asks for the indicator once per tool call" do
      3.times { |index| service.send(:track_tool_call, double(:call, name: "tool_#{index}")) }

      expect(messages_api)
        .to have_received(:send_typing_indicator).with(message_id: "wamid.INBOUND").exactly(3).times
    end

    context "when the inbound message is not known" do
      let(:inbound_message_id) { nil }

      it "asks for nothing" do
        service.send(:track_tool_call, double(:call, name: "list_open_phases"))

        expect(messages_api).not_to have_received(:send_typing_indicator)
      end
    end

    it "does not let a failing indicator cost the turn" do
      allow(messages_api).to receive(:send_typing_indicator).and_raise(StandardError, "gateway")

      expect { service.send(:track_tool_call, double(:call, name: "list_open_phases")) }
        .not_to raise_error
    end
  end
end
