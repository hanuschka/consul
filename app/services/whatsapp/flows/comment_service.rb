class Whatsapp::Flows::CommentService < Whatsapp::Flows::BaseService
  # Catalog D27 and D28 — the comment question and the message that answers
  # it. One service because the prompt writes the context key the creation
  # reads back.

  # D27. One pill beside the question, and it is the way out rather than an
  # answer: the reply the bot wants here is the comment itself, so anything
  # tappable that could pass for an answer is something to tap instead of
  # writing — which is exactly what went wrong when the question was phrased
  # as "möchten Sie etwas ergänzen?" and the word "Ja" was published under the
  # citizen's name.
  def self.prompt(conversation:, proposal:)
    new(conversation: conversation).prompt(proposal)
  end

  # Refused rather than published. The question now asks for the text itself,
  # but the wording lives in a locale file that anyone can edit back, and what
  # a mistake there costs is a citizen's name under the word "Ja" on a public
  # page. Deliberately only the words that cannot be a contribution on their
  # own — a short comment is still a comment.
  CONFIRMATION_WORDS = %w[ja nein jo jep nee nö ok okay yes no yep nope].freeze

  # D28. One message commits, like the support tap and unlike a proposal: a
  # comment is short enough that showing it back for confirmation would cost
  # more taps than writing it did.
  def self.create(conversation:, body:)
    new(conversation: conversation).create(body)
  end

  def prompt(proposal)
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_COMMENT)
    @conversation.store_comment_proposal_id!(proposal.id)

    send_prompt("whatsapp.bot.comment.prompt")
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

    # Asked after the proposal and the permission, not before: a citizen who
    # answers "ja" about a contribution that has since been deleted or closed
    # is owed that news rather than an invitation to write a comment nothing
    # would accept.
    return send_confirmation_only if confirmation_only?(comment_body)

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

    def confirmation_only?(comment_body)
      CONFIRMATION_WORDS.include?(comment_body.downcase.delete("!.,?"))
    end

    # The question and every re-asking of it carry the same single escape, so
    # the step can always be left without commenting — the citizen who has
    # nothing more to say must not have to abandon the conversation to get out
    # of it.
    def send_prompt(body_key)
      Whatsapp::Send.buttons(
        account: account,
        body: Whatsapp.phrase(body_key),
        buttons: [Whatsapp::Send.recovery_button(:cancel)]
      )
    end

    def send_empty
      send_prompt("whatsapp.bot.comment.prompt")
    end

    def send_confirmation_only
      send_prompt("whatsapp.bot.comment.confirmation_only")
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
