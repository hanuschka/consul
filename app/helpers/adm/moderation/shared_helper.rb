module Adm::Moderation::SharedHelper
  def moderation_status_badge(record)
    if record.hidden?
      [:hide, "kern-badge--danger"]
    elsif record.ignored_flag?
      [:ignored, "kern-badge--info"]
    else
      [:pending, "kern-badge--warning"]
    end
  end

  def moderation_resource_reachable?(record)
    record.projekt.present?
  end

  def moderation_comment_resource_reachable?(comment)
    commentable = comment.commentable
    return false if commentable.nil?

    polymorphic_path(commentable).present?
  rescue ActionController::UrlGenerationError, NoMethodError, ArgumentError, URI::Error
    false
  end
end
