module NotificationServices
  class ProjektArgumentsNotifier < ApplicationService
    def initialize(projekt_phase_id)
      @projekt_phase = ProjektPhase.find(projekt_phase_id)
    end

    def call
      projekt_subscribers.find_each do |user|
        NotificationServiceMailer.projekt_arguments(user.id, @projekt_phase.id).deliver_later
        Notification.add(user, @projekt_phase)
        Activity.log(user, "email", @projekt_phase)
      end
    end

    private

      def projekt_subscribers
        if @projekt_phase.projekt_arguments.exists?
          @projekt_phase.projekt.actual_subscribers
        else
          User.none
        end
      end
  end
end
