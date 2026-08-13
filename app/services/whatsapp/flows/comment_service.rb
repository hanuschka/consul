class Whatsapp::Flows::CommentService < Whatsapp::Flows::BaseService
  # Catalog D27 and D28 — the comment question and the message that answers
  # it. One service because the prompt writes the context key the creation
  # reads back.

  # D27. No buttons: the reply the bot wants here is the comment itself, and a
  # pill next to that question would only give the citizen something to tap
  # instead of writing.
  def self.prompt(conversation:, proposal:)
    new(conversation: conversation).prompt(proposal)
  end

  # D28. One message commits, like the support tap and unlike a proposal: a
  # comment is short enough that showing it back for confirmation would cost
  # more taps than writing it did.
  def self.create(conversation:, body:)
    new(conversation: conversation).create(body)
  end

  def prompt(proposal)
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_COMMENT)
    @conversation.store_comment_proposal_id!(proposal.id)

    Whatsapp::Send.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.comment.prompt")
    )
  end

  # Which of the two confirmations the citizen gets is decided by the record
  # that was just written, not by a setting: this portal publishes comments
  # immediately and hides them afterwards, so telling everyone their comment
  # is "being reviewed" would be false. If a moderation rule does hide it on
  # creation, the reviewing copy is the true one and this asks the row.
  def create(body)
    comment_body = body.to_s.strip

    return send_empty if comment_body.blank?
    return send_gone if proposal.blank?
    return send_not_allowed if !comments_allowed?

    comment = Comment.build(proposal, user, comment_body)

    return send_invalid if !comment.save

    @conversation.reset_flow!

    send_confirmation(comment)
  end

  private

    def user
      account.user
    end

    def proposal
      return @proposal if defined?(@proposal)

      @proposal = Proposal.find_by(id: @conversation.comment_proposal_id)
    end

    def comments_allowed?
      projekt_phase = proposal.projekt_phase

      return false if projekt_phase.blank?

      projekt_phase.comments_allowed?(user, proposal)
    end

    def send_confirmation(comment)
      copy_key = comment.hidden? ? "whatsapp.bot.comment.pending" : "whatsapp.bot.comment.published"

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase(copy_key)
      )
    end

    def send_empty
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.comment.prompt")
      )
    end

    def send_invalid
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.comment.invalid")
      )
    end

    def send_not_allowed
      @conversation.reset_flow!

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.comment.closed")
      )
    end

    def send_gone
      @conversation.reset_flow!

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.support.gone")
      )
    end
end
