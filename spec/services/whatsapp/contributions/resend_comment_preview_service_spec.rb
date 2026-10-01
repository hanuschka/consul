require "rails_helper"

describe Whatsapp::Contributions::ResendCommentPreviewService do
  # The comment's counterpart of the draft's re-show: a posting pill tapped under
  # earlier words posts nothing and is answered with the words that stand now.
  let(:account) { double(:account) }
  let(:conversation) { double(:conversation, whatsapp_account: account) }

  let(:tool) { instance_double(Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation) }

  before do
    allow(Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation)
      .to receive(:new).with(conversation: conversation).and_return(tool)
    allow(tool).to receive(:call).and_return(ToolHalt.new("shown"))

    allow(Whatsapp::AiAssistant::BotCopyService).to receive(:call) do |lines:, **|
      lines
    end
  end

  def resend
    Whatsapp::Contributions::ResendCommentPreviewService.call(conversation: conversation)
  end

  it "shows the comment under the fixed question with posting, changing and the way out" do
    resend

    expect(tool).to have_received(:call).with(
      question: I18n.t("whatsapp.bot.comment.outdated_question"),
      buttons: [
        { "action_id" => "comment_post", "label" => "" },
        {
          "action_id" => "comment_prompt",
          "label" => I18n.t("whatsapp.bot.buttons.comment_revise")
        },
        { "action_id" => "cancel", "label" => "" }
      ]
    )
  end

  it "asks for both lines in one go" do
    resend

    expect(Whatsapp::AiAssistant::BotCopyService).to have_received(:call).once
  end

  it "says it went out" do
    expect(resend).to be(true)
  end
end
