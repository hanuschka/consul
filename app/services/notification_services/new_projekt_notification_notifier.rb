module NotificationServices
  class NewProjektNotificationNotifier < ApplicationService
    def initialize(projekt_notification_id)
      @projekt_notification = ProjektNotification.find(projekt_notification_id)
    end

    def call
      projekt_subscribers.find_each do |user|
        NotificationServiceMailer.new_projekt_notification(user.id, @projekt_notification.id).deliver_later
        Notification.add(user, @projekt_notification)
        Activity.log(user, "email", @projekt_notification)
      end
    end

    private

      def projekt_subscribers
        @projekt_notification.projekt_phase.projekt.actual_subscribers
      end
  end
end
