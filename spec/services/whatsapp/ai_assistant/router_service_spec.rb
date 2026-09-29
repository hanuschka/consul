require "rails_helper"

describe Whatsapp::AiAssistant::RouterService do
  let(:messages_api) do
    instance_double(
      WhatsappApi::Resources::Messages,
      send_typing_indicator: double(:response, success?: true)
    )
  end

  let(:conversation) { double(:conversation, step: nil) }

  let(:service) do
    Whatsapp::AiAssistant::RouterService.new(
      conversation: conversation,
      inbound_text: "The citizen tapped the button \"Von vorne loslegen\" (action menu).",
      inbound_message_id: "wamid.INBOUND",
      typing_message_id: typing_message_id
    )
  end

  let(:typing_message_id) { "wamid.INBOUND" }

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

    # A retry answers an older inbound while the citizen watches the pill they
    # have just tapped, and WhatsApp only shows the bubble under that one.
    context "when the turn answers an older message than the one the citizen is under" do
      let(:typing_message_id) { "wamid.TAPPED" }

      it "hangs the bubble on the message the citizen is under" do
        service.send(:track_tool_call, double(:call, name: "list_open_phases"))

        expect(messages_api).to have_received(:send_typing_indicator).with(message_id: "wamid.TAPPED")
      end
    end

    context "when there is no message to hang the bubble on" do
      let(:typing_message_id) { nil }

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
