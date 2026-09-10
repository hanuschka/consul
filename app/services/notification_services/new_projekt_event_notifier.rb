module NotificationServices
  class NewProjektEventNotifier < ApplicationService
    def initialize(projekt_event_id)
      @projekt_event = ProjektEvent.find(projekt_event_id)
    end

    def call
      NotificationServices::NotifySubscribers.call(
        users: users_to_notify,
        mailer_action: "new_projekt_event",
        mailer_record: @projekt_event,
        notifiable: @projekt_event,
        actionable: @projekt_event
      )
    end

    private

      def users_to_notify
        projekt_subscribers.uniq(&:id).reject(&:not_actual?)
      end

      def projekt_subscribers
        return [] if @projekt_event.projekt_phase.blank?

        @projekt_event.projekt_phase.projekt.subscribers.to_a
      end
  end
end
