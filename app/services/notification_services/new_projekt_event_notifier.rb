module NotificationServices
  class NewProjektEventNotifier < ApplicationService
    def initialize(projekt_event_id)
      @projekt_event = ProjektEvent.find(projekt_event_id)
    end

    def call
      projekt_subscribers.find_each do |user|
        NotificationServiceMailer.new_projekt_event(user.id, @projekt_event.id).deliver_later
        Notification.add(user, @projekt_event)
        Activity.log(user, "email", @projekt_event)
      end
    end

    private

      def projekt_subscribers
        if @projekt_event.projekt_phase.blank?
          User.none
        else
          @projekt_event.projekt_phase.projekt.actual_subscribers
        end
      end
  end
end
