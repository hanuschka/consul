module NotificationServices
  class ProjektArgumentsNotifier < ApplicationService
    def initialize(projekt_phase_id)
      @projekt_phase = ProjektPhase.find(projekt_phase_id)
    end

    def call
      NotificationServices::NotifySubscribers.call(
        users: users_to_notify,
        mailer_action: "projekt_arguments",
        mailer_record: @projekt_phase,
        notifiable: @projekt_phase,
        actionable: @projekt_phase
      )
    end

    private

      def users_to_notify
        projekt_subscribers.uniq(&:id).reject(&:not_actual?)
      end

      def projekt_subscribers
        return [] if @projekt_phase.projekt_arguments.none?

        @projekt_phase.projekt.subscribers.to_a
      end
  end
end
