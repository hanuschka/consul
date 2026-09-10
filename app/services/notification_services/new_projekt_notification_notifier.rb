module NotificationServices
  class NewProjektNotificationNotifier < ApplicationService
    def initialize(projekt_notification_id)
      @projekt_notification = ProjektNotification.find(projekt_notification_id)
    end

    def call
      NotificationServices::NotifySubscribers.call(
        users: users_to_notify,
        mailer_action: "new_projekt_notification",
        mailer_record: @projekt_notification,
        notifiable: @projekt_notification,
        actionable: @projekt_notification
      )
    end

    private

      def users_to_notify
        projekt_subscribers.uniq(&:id).reject(&:not_actual?)
      end

      def projekt_subscribers
        @projekt_notification.projekt_phase.projekt.subscribers.to_a
      end
  end
end
