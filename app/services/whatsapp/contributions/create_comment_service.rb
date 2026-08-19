class Whatsapp::Contributions::CreateCommentService < ApplicationService
  # Writes a citizen's comment onto a published proposal, with the preconditions
  # that decide whether it may be written at all. Extracted out of the scripted
  # comment step, which owned the write and the sentences around it together: the
  # sentences are the assistant's now, and this answers only what happened.
  #
  # Returns the saved Comment, or a symbol naming what stopped it. The caller
  # turns that into words — nothing here sends anything.

  # Refused rather than published. The tool asks the assistant for the comment
  # text itself, but a model that read "ja" as the comment would put a citizen's
  # name under the word "Ja" on a public page, and that is not recoverable from a
  # chat. Deliberately only the words that cannot be a contribution on their own —
  # a short comment is still a comment.
  CONFIRMATION_WORDS = %w[ja nein jo jep nee nö ok okay yes no yep nope].freeze

  def initialize(proposal:, user:, body:)
    @proposal = proposal
    @user = user
    @body = body.to_s.strip
  end

  def call
    return :not_linked if @user.blank?
    return :gone if @proposal.blank?
    return :blank if @body.blank?
    return :confirmation_only if confirmation_only?
    return :closed if !comments_allowed?

    comment = ::Comment.build(@proposal, @user, @body)

    return :invalid if !comment.save

    comment
  end

  private

    def comments_allowed?
      projekt_phase = @proposal.projekt_phase

      return false if projekt_phase.blank?

      projekt_phase.comments_allowed?(@user, @proposal)
    end

    def confirmation_only?
      CONFIRMATION_WORDS.include?(@body.downcase.delete("!.,?"))
    end
end
