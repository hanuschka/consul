class Whatsapp::Flows::CommentPromptService < Whatsapp::Flows::BaseService
  # Catalog D27. No buttons: the reply the bot wants here is the comment itself,
  # and a pill next to that question would only give the citizen something to
  # tap instead of writing.
  def initialize(conversation:, proposal:)
    super(conversation: conversation)
    @proposal = proposal
  end

  def call
    @conversation.update!(step: "awaiting_comment")
    @conversation.merge_context!(comment_proposal_id: @proposal.id)

    Whatsapp::Outbound.text(
      account: account,
      body: I18n.t("whatsapp.bot.comment.prompt")
    )
  end
end
