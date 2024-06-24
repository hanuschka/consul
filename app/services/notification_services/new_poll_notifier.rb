module NotificationServices
  class NewPollNotifier < ApplicationService
    def initialize(poll_id)
      @poll = Poll.find(poll_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_poll(user.id, @poll.id).deliver_later
        Notification.add(user, @poll)
        Activity.log(user, "email", @poll)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id)
      end

      def projekt_phase_subscribers
        return [] unless @poll.projekt_phase.present?

        @poll.projekt_phase.subscribers.to_a
      end
  end
end
