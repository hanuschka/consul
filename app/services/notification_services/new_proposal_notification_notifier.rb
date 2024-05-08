module NotificationServices
  class NewProposalNotificationNotifier < ApplicationService
    def initialize(proposal_notification_id)
      @proposal_notification = ProposalNotification.find(proposal_notification_id)
      @proposal = @proposal_notification.proposal
    end

    def call
      users_to_notify_ids.each do |user_id|
        NotificationServiceMailer.new_proposal_notification(user_id, @proposal_notification.id).deliver_later
      end
    end

    private

      def users_to_notify_ids
        @proposal.followers.email_digest.ids - [@proposal.author_id]
      end
  end
end
