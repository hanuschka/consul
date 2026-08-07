class Whatsapp::Flows::CommentPromptService < ApplicationService
  # Catalog D27. No buttons: the reply the bot wants here is the comment itself,
  # and a pill next to that question would only give the citizen something to
  # tap instead of writing.
  def initialize(conversation:, proposal:)
    @conversation = conversation
    @proposal = proposal
  end

  def call
    @conversation.update!(step: "awaiting_comment")
    @conversation.merge_context!(comment_proposal_id: @proposal.id)

    Whatsapp::Outbound.text(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.comment.prompt")
    )
  end
end
