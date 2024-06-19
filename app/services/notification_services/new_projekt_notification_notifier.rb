module NotificationServices
  class NewProjektNotificationNotifier < ApplicationService
    def initialize(projekt_notification_id)
      @projekt_notification = ProjektNotification.find(projekt_notification_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_projekt_notification(user.id, @projekt_notification.id).deliver_later
        Notification.add(user, @projekt_notification)
        Activity.log(user, "email", @projekt_notification)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id)
      end

      def projekt_phase_subscribers
        @projekt_notification.projekt_phase.subscribers.to_a
      end
  end
end
