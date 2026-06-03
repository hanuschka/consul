module RecipientGroups
  module FilterResolvers
    class CommentAuthors < Base
      def emails
        scope = Comment.all
        scope = scope.where(commentable_type: params[:commentable_type]) if params[:commentable_type].present?
        scope = scope.where(commentable_id: params[:commentable_id]) if params[:commentable_id].present?

        user_ids = scope.pluck(:user_id).uniq
        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
