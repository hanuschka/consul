class Whatsapp::Contributions::CreateCommentService < ApplicationService
  # Writes a citizen's comment onto a published proposal, with the preconditions
  # that decide whether it may be written at all. Extracted out of the scripted
  # comment step, which owned the write and the sentences around it together: the
  # sentences are the assistant's now, and this answers only what happened.
  #
  # Returns the saved Comment, or a symbol naming what stopped it. The caller
  # turns that into words — nothing here sends anything.

  # Refused rather than published. A model that read "ja" as the comment would put
  # a citizen's name under the word "Ja" on a public page, and that is not
  # recoverable from a chat. Deliberately only the words that cannot be a
  # contribution on their own — a short comment is still a comment.
  CONFIRMATION_WORDS = %w[ja nein jo jep nee nö ok okay yes no yep nope].freeze

  # Why this comment may not be written, or nil when it may. Its own entry point
  # because the flow now asks twice: once before the citizen is asked to confirm
  # their words, and again before those words are written. A comment refused only
  # at the write is a citizen who confirmed a comment onto a closed thread.
  def self.refusal(proposal:, user:, body:)
    return :not_linked if user.blank?
    return :gone if proposal.blank?
    return :blank if body.to_s.strip.blank?
    return :confirmation_only if confirmation_only?(body)
    return :closed if !comments_allowed?(proposal: proposal, user: user)

    nil
  end

  def self.confirmation_only?(body)
    CONFIRMATION_WORDS.include?(body.to_s.strip.downcase.delete("!.,?"))
  end

  def self.comments_allowed?(proposal:, user:)
    projekt_phase = proposal.projekt_phase

    return false if projekt_phase.blank?

    projekt_phase.comments_allowed?(user, proposal)
  end

  def initialize(proposal:, user:, body:)
    @proposal = proposal
    @user = user
    @body = body.to_s.strip
  end

  def call
    refusal = self.class.refusal(proposal: @proposal, user: @user, body: @body)

    return refusal if refusal.present?
    return :duplicate if already_posted?

    comment = ::Comment.build(@proposal, @user, @body)

    return :invalid if !comment.save

    comment
  end

  private

    # Checked at the write only, not in the refusal the drafting tool asks first: a
    # turn that saved the comment and then failed before answering is retried with
    # the same words, and the retry must find the comment rather than post it twice.
    # Hidden ones count — a comment moderation took down is still one they posted.
    def already_posted?
      ::Comment.with_hidden.where(commentable: @proposal, user_id: @user.id, body: @body).exists?
    end
end
