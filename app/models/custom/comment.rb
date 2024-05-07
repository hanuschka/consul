require_dependency Rails.root.join("app", "models", "comment").to_s

class Comment < ApplicationRecord
  scope :seen, -> { where.not(ignored_flag_at: nil) }
  scope :unseen, -> { where(ignored_flag_at: nil) }
  scope :created_after_date, ->(datetime) {
    return if datetime.blank?

    where("created_at > ?", datetime)
  }

  delegate :comments_allowed?, to: :projekt, allow_nil: true

  def next_comments
    self.class
      .where(commentable_id: commentable_id, commentable_type: commentable_type)
      .where("id > ?", id)
  end

  def projekt
    return commentable if commentable.is_a?(Projekt)

    commentable&.projekt.presence if commentable.respond_to?(:projekt)
  end
end
