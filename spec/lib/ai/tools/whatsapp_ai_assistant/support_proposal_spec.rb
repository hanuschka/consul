require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::SupportProposal do
  # A tapped support button never reaches this tool — the inbound side registers
  # it — so there is no offer left to check here. What these cover is that the
  # recap is composed from the record, and that a refusal sends nothing.
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::SupportProposal.new(conversation: conversation)
  end

  let(:user) { double(:user) }
  let(:account) { double(:account, user: user) }
  let(:conversation) { double(:conversation, whatsapp_account: account) }

  before { allow(Whatsapp::Send).to receive(:message_block) }

  describe "once the support goes in" do
    let(:proposal) { double(:proposal, title: "Mehr Bänke") }

    before do
      allow(Proposal).to receive(:find_by).with(id: 482).and_return(proposal)
      allow(Whatsapp::Contributions::RegisterSupportService).to receive(:call).and_return(43)
      allow(Whatsapp::SupportRecap)
        .to receive(:registered_block).and_return("Unterstützt: Mehr Bänke")
    end

    it "registers the support and reports the new count" do
      expect(tool.execute(contribution_id: 482)).to include(supported: true, supports: 43)
    end

    it "sends the proposal and the count composed from the record" do
      expect(Whatsapp::SupportRecap)
        .to receive(:registered_block)
        .with(account: account, proposal: proposal, supports: 43)

      tool.execute(contribution_id: 482)
    end

    it "sends the recap to the citizen" do
      tool.execute(contribution_id: 482)

      expect(Whatsapp::Send)
        .to have_received(:message_block)
        .with(account: account, block: "Unterstützt: Mehr Bänke")
    end

    it "tells the model not to repeat what was already sent" do
      expect(tool.execute(contribution_id: 482)[:hint]).to match(/already been sent/)
    end
  end

  describe "when the proposal has been retired since it was mentioned" do
    before do
      allow(Whatsapp::Contributions::RegisterSupportService).to receive(:call).and_return(:gone)
    end

    it "says so" do
      expect(tool.execute(contribution_id: 482)[:error]).to match(/no longer has a public page/)
    end

    it "sends nothing" do
      tool.execute(contribution_id: 482)

      expect(Whatsapp::Send).not_to have_received(:message_block)
    end
  end

  describe "with an unlinked number" do
    let(:user) { nil }

    it "asks for an account before it asks about the button" do
      expect(tool.execute(contribution_id: 482)[:error]).to match(/not linked to an account/)
    end
  end
end
