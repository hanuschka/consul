module NotificationServices
  class NewProposalNotificationNotifier < ApplicationService
    def initialize(proposal_notification_id)
      @proposal_notification = ProposalNotification.find(proposal_notification_id)
      @proposal = @proposal_notification.proposal
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_proposal_notification(user.id, @proposal_notification.id).deliver_later
        Notification.add(user, @proposal_notification)
        Activity.log(user, "email", @proposal_notification)
      end
    end

    private

      def users_to_notify
        @proposal.followers.to_a.reject { |user| user.id == @proposal.author_id }
      end
  end
end
