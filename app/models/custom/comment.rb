require_dependency Rails.root.join("app", "models", "comment").to_s

class Comment < ApplicationRecord
  scope :seen, -> { where.not(ignored_flag_at: nil) }
  scope :unseen, -> { where(ignored_flag_at: nil) }
  scope :created_after_date, ->(datetime) {
    return if datetime.blank?

    where("created_at > ?", datetime)
  }

  delegate :comments_allowed?, to: :projekt, allow_nil: true

  # Catalog B12's "new comments" trigger, hooked here rather than in the
  # comments controller so a comment written through the bot notifies the
  # proposal's author exactly as a comment written on the website does.
  after_create_commit :notify_whatsapp_author

  def next_comments
    self.class
      .where(commentable_id: commentable_id, commentable_type: commentable_type)
      .where("id > ?", id)
  end

  def projekt
    return commentable if commentable.is_a?(Projekt)

    commentable&.projekt.presence if commentable.respond_to?(:projekt)
  end

  private

    # Not for a comment the author left on their own proposal: being told about
    # yourself is the fastest way to get a notification switched off.
    def notify_whatsapp_author
      return if commentable_type != "Proposal"
      return if !::Whatsapp.enabled?
      return if commentable&.author_id.blank? || commentable.author_id == user_id

      Whatsapp::NotifyProposalStatusJob.perform_later(commentable_id, "new_comments")
    end
end
