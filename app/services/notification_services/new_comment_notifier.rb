module NotificationServices
  class NewCommentNotifier < ApplicationService
    def initialize(comment_id)
      @comment = Comment.find(comment_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_comment(user.id, @comment.id).deliver_later
        Notification.add(user, @comment)
        Activity.log(user, "email", @comment)
      end
    end

    private

      def users_to_notify
        [administrators, moderators, projekt_managers, projekt_phase_subscribers]
          .flatten.uniq(&:id).reject { |user| user.id == @comment.user_id }
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_comment: true).to_a
      end

      def moderators
        User.joins(:moderator).where(adm_email_on_new_comment: true).to_a
      end

      def projekt_managers
        User.joins(projekt_manager: :projekt_manager_assignments)
          .where(adm_email_on_new_comment: true)
          .where(projekt_manager_assignments: { projekt_id: @comment&.projekt&.id })
          .where("projekt_manager_assignments.permissions @> ARRAY[?]::text[]", ["get_notifications"]).to_a
      end

      def projekt_phase_subscribers
        if @comment.commentable.is_a?(ProjektPhase::CommentPhase)
          @comment.commentable.subscribers.to_a
        elsif @comment.commentable.respond_to?(:projekt_phase)
          @comment.commentable.projekt_phase.subscribers.to_a
        else
          []
        end
      end
  end
end
