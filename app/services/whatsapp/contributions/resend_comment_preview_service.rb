class Whatsapp::Contributions::ResendCommentPreviewService < ApplicationService
  # The comment shown again as it stands, for a citizen who tapped the posting pill
  # under a preview of earlier words (Whatsapp::PreviewVersion). The same answer
  # Whatsapp::Drafting::ResendPreviewService gives for a draft: nothing is posted on
  # a yes given to other words, and the preview they would have needed goes out
  # instead, through the tool every comment preview goes through. True when it did.
  QUESTION_KEY = "whatsapp.bot.comment.outdated_question".freeze
  REVISE_LABEL_KEY = "whatsapp.bot.buttons.comment_revise".freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    question, revise_label = ::Whatsapp::AiAssistant::BotCopyService.call(
      account: @conversation.whatsapp_account,
      lines: [::Whatsapp.copy(QUESTION_KEY), ::Whatsapp.copy(REVISE_LABEL_KEY)]
    )

    tool = ::Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation.new(
      conversation: @conversation
    )

    tool.call(question: question, buttons: buttons(revise_label)).is_a?(::ToolHalt)
  end

  private

    # The posting pill and the way out carry fixed labels. The way to change the
    # words has none of its own, so it is given one from the copy.
    def buttons(revise_label)
      [
        { "action_id" => "comment_post", "label" => "" },
        { "action_id" => "comment_prompt", "label" => revise_label },
        { "action_id" => "cancel", "label" => "" }
      ]
    end
end
