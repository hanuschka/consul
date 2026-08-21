require "rails_helper"

describe Ai::Tools::WhatsappAiAssistant::SupportProposal do
  # Support cannot be withdrawn, and the offer recorded on the conversation used to
  # say only that *a* support button had been shown. These cover the part that
  # matters: which proposal it was shown for.
  subject(:tool) do
    Ai::Tools::WhatsappAiAssistant::SupportProposal.new(conversation: conversation)
  end

  let(:user) { double(:user) }
  let(:account) { double(:account, user: user) }
  let(:conversation) { double(:conversation, whatsapp_account: account) }

  before { allow(conversation).to receive(:confirmation_offered?).and_return(false) }

  describe "the confirmation gate" do
    it "refuses when no support button was offered for this proposal" do
      answer = tool.execute(contribution_id: 482)

      expect(answer[:error]).to match(/did not offer the support button for proposal 482/)
    end

    it "registers nothing when it refuses" do
      expect(Whatsapp::Contributions::RegisterSupportService).not_to receive(:call)

      tool.execute(contribution_id: 482)
    end

    # The reason the offer is recorded with its parameter: a bare "support" was
    # satisfied by a pill shown for any proposal at all.
    it "refuses when the button was offered for a different proposal" do
      allow(conversation).to receive(:confirmation_offered?).with("support-482").and_return(false)
      allow(conversation).to receive(:confirmation_offered?).with("support-99").and_return(true)

      expect(tool.execute(contribution_id: 482)[:error])
        .to match(/did not offer the support button for proposal 482/)
    end
  end

  describe "once the button was offered for this proposal" do
    let(:proposal) { double(:proposal, title: "Mehr Bänke") }

    before do
      allow(conversation).to receive(:confirmation_offered?).with("support-482").and_return(true)
      allow(Proposal).to receive(:find_by).with(id: 482).and_return(proposal)
      allow(Whatsapp::Contributions::RegisterSupportService).to receive(:call).and_return(43)
      allow(Whatsapp::SupportRecap).to receive(:block).and_return("Unterstützt: Mehr Bänke")
      allow(Whatsapp::MessageBlock).to receive(:chunks).and_return(["Unterstützt: Mehr Bänke"])
      allow(Whatsapp::Send).to receive(:text)
    end

    it "registers the support and reports the new count" do
      expect(tool.execute(contribution_id: 482)).to include(supported: true, supports: 43)
    end

    it "sends the proposal and the count composed from the record" do
      expect(Whatsapp::SupportRecap)
        .to receive(:block)
        .with(account: account, proposal: proposal, supports: 43)

      tool.execute(contribution_id: 482)
    end

    it "tells the model not to repeat what was already sent" do
      expect(tool.execute(contribution_id: 482)[:hint]).to match(/already been sent/)
    end
  end

  describe "with an unlinked number" do
    let(:user) { nil }

    it "asks for an account before it asks about the button" do
      expect(tool.execute(contribution_id: 482)[:error]).to match(/not linked to an account/)
    end
  end
end
