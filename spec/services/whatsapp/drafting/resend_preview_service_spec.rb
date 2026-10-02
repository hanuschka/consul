require "rails_helper"

describe Whatsapp::Drafting::ResendPreviewService do
  # A publishing pill tapped under a preview of an earlier version publishes
  # nothing: the citizen is shown the version that stands now, through the same
  # tool every preview goes through.
  let(:account) { double(:account) }
  let(:additions) { [] }
  let(:conversation) do
    double(:conversation, whatsapp_account: account, additions_beyond_idea: additions)
  end

  let(:tool) { instance_double(Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation) }
  let(:tool_result) { ToolHalt.new("shown") }

  before do
    allow(Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation)
      .to receive(:new).with(conversation: conversation).and_return(tool)
    allow(tool).to receive(:call).and_return(tool_result)

    allow(Whatsapp::AiAssistant::BotCopyService).to receive(:call) do |lines:, **|
      lines
    end
  end

  def resend
    Whatsapp::Drafting::ResendPreviewService.call(conversation: conversation)
  end

  it "shows the draft under the fixed question, with fixed pills only" do
    resend

    expect(tool).to have_received(:call).with(
      question: I18n.t("whatsapp.bot.preview.outdated_question"),
      buttons: Whatsapp::Drafting::ResendPreviewService::BUTTONS
    )
  end

  it "offers publishing, changing the draft and the way out" do
    expect(Whatsapp::Drafting::ResendPreviewService::BUTTONS.map { |button| button["action_id"] })
      .to eq(%w[draft_publish draft_revise cancel])
  end

  it "asks for the lines in the citizen's language" do
    resend

    expect(Whatsapp::AiAssistant::BotCopyService).to have_received(:call).with(
      account: account, lines: [I18n.t("whatsapp.bot.preview.outdated_question")]
    )
  end

  it "says it went out" do
    expect(resend).to be(true)
  end

  context "when the tool refuses to show it" do
    let(:tool_result) { { error: "There is no draft in this conversation." } }

    it "says it did not go out" do
      expect(resend).to be(false)
    end
  end

  # Where the draft carries things the citizen never said, the tool refuses the
  # preview without a note naming them.
  context "when the draft carries additions beyond the citizen's words" do
    let(:additions) { ["eine Bank", "ein Baum"] }

    it "names them in the note" do
      resend

      expect(tool).to have_received(:call).with(
        hash_including(
          additions_note: I18n.t(
            "whatsapp.bot.preview.outdated_additions_note", additions: "eine Bank, ein Baum"
          )
        )
      )
    end
  end
end
