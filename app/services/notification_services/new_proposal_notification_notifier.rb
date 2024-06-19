module NotificationServices
  class NewProposalNotificationNotifier < ApplicationService
    include NotificationServices::SharedMethods

    def initialize(proposal_notification_id)
      @proposal_notification = ProposalNotification.find(proposal_notification_id)
      @proposal = @proposal_notification.proposal
    end

    def call
      run_at = Time.zone.now

      users_to_notify.in_groups_of(batch_size, false).each do |users_batch|
        users_batch.each do |user|
          NotificationServiceMailer.delay(queue_options(run_at))
            .new_proposal_notification(user.id, @proposal_notification.id)
          Activity.log(user, "email", @proposal_notification)
          Notification.add(user, @proposal_notification)
        end

        run_at += batch_interval
      end
    end

    private

      def users_to_notify
        @proposal.followers.to_a.reject { |user| user.id == @proposal.author_id }
      end
  end
end
