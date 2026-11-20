module NotificationServices
  class ProjektQuestionsNotifier < ApplicationService
    def initialize(projekt_phase_id)
      @projekt_phase = ProjektPhase.find(projekt_phase_id)
    end

    def call
      projekt_subscribers.find_each do |user|
        NotificationServiceMailer.projekt_questions(user.id, @projekt_phase.id).deliver_later
        Notification.add(user, @projekt_phase)
        Activity.log(user, "email", @projekt_phase)
      end
    end

    private

      def projekt_subscribers
        if @projekt_phase.questions.exists?
          @projekt_phase.projekt.actual_subscribers
        else
          User.none
        end
      end
  end
end
