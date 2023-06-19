module NotificationServices
  class ProjektQuestionsNotifier < ApplicationService
    def initialize(projekt_id)
      @projekt = Projekt.find(projekt_id)
    end

    def call
      users_to_notify_ids.each do |user_id|
        NotificationServiceMailer.projekt_questions(user_id, @projekt.id).deliver_later
      end
    end

    private

      def users_to_notify_ids
        [projekt_subscriber_ids].flatten.uniq
      end

      def projekt_subscriber_ids
        return [] unless @projekt.questions.any?

        @projekt.question_phase.subscribers.ids
      end
  end
end