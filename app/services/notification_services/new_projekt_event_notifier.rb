module NotificationServices
  class NewProjektEventNotifier < ApplicationService
    def initialize(projekt_event_id)
      @projekt_event = ProjektEvent.find(projekt_event_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_projekt_event(user.id, @projekt_event.id).deliver_later
        Notification.add(user, @projekt_event)
        Activity.log(user, "email", @projekt_event)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id)
      end

      def projekt_phase_subscribers
        return [] unless @projekt_event.projekt_phase.present?

        @projekt_event.projekt_phase.subscribers.to_a
      end
  end
end
