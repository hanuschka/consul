load Rails.root.join("app", "models", "legislation", "annotation.rb")

class Legislation::Annotation < ApplicationRecord
  delegate :projekt_phase, :permission_problem, :comments_allowed?, to: :draft_version
  alias_method :legislation_phase, :projekt_phase

  def create_first_comment
    annotation_comment = comments.create(body: text, user: author)
    NotificationServices::NewCommentNotifier.call(annotation_comment.id) if annotation_comment.persisted?
  end
end
