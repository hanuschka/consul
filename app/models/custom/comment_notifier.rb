require_dependency Rails.root.join("app", "models", "comment_notifier").to_s

class CommentNotifier

  private

    def email_on_comment?
      return false unless @comment.root?

      commentable_author = @comment.commentable.author

      return false unless commentable_author.present?

      # The author of a resource is always emailed when their resource is
      # commented on, regardless of their email_on_comment preference.
      commentable_author != @author
    end

    def email_on_comment_reply?
      return false unless @comment.reply?

      parent_author = @comment.parent.author

      return false unless parent_author.present?
      return false if parent_author == @author

      # If the parent author is also the resource author, always email them,
      # regardless of their email_on_comment_reply preference.
      return true if parent_author == @comment.commentable.author

      parent_author.email_on_comment_reply?
    end
end
