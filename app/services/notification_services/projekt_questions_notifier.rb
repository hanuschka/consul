module NotificationServices
  class ProjektQuestionsNotifier < ApplicationService
    def initialize(projekt_phase_id)
      @projekt_phase = ProjektPhase.find(projekt_phase_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.projekt_questions(user.id, @projekt_phase.id).deliver_later
        Notification.add(user, @projekt_phase)
        Activity.log(user, "email", @projekt_phase)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id)
      end

      def projekt_phase_subscribers
        return [] unless @projekt_phase.questions.any?

        @projekt_phase.subscribers.to_a
      end
  end
end
