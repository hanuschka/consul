class Whatsapp::Flows::CreateCommentService < ApplicationService
  # Catalog D28. One message commits, like the support tap and unlike a
  # proposal: a comment is short enough that showing it back for confirmation
  # would cost more taps than writing it did.
  #
  # Which of the two confirmations the citizen gets is decided by the record
  # that was just written, not by a setting: this portal publishes comments
  # immediately and hides them afterwards, so telling everyone their comment is
  # "being reviewed" would be false. If a moderation rule does hide it on
  # creation, the reviewing copy is the true one and this asks the row.
  def initialize(conversation:, body:)
    @conversation = conversation
    @body = body.to_s.strip
  end

  def call
    return send_empty if @body.blank?
    return send_gone if proposal.blank?
    return send_not_allowed if !comments_allowed?

    comment = Comment.build(proposal, user, @body)

    return send_invalid if !comment.save

    @conversation.reset_flow!

    send_confirmation(comment)
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def user
      account.user
    end

    def proposal
      return @proposal if defined?(@proposal)

      @proposal = Proposal.find_by(id: @conversation.context["comment_proposal_id"])
    end

    def comments_allowed?
      projekt_phase = proposal.projekt_phase

      return false if projekt_phase.blank?

      projekt_phase.comments_allowed?(user, proposal)
    end

    def send_confirmation(comment)
      copy_key = comment.hidden? ? "whatsapp.bot.comment.pending" : "whatsapp.bot.comment.published"

      Whatsapp::Outbound.text(account: account, body: I18n.t(copy_key))
    end

    def send_empty
      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.comment.prompt"))
    end

    def send_invalid
      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.comment.invalid"))
    end

    def send_not_allowed
      @conversation.reset_flow!

      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.comment.closed"))
    end

    def send_gone
      @conversation.reset_flow!

      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.support.gone"))
    end
end
