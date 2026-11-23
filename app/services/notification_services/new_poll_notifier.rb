module NotificationServices
  class NewPollNotifier < ApplicationService
    def initialize(poll_id)
      @poll = Poll.find(poll_id)
    end

    def call
      projekt_subscribers.find_each do |user|
        NotificationServiceMailer.new_poll(user.id, @poll.id).deliver_later
        Notification.add(user, @poll)
        Activity.log(user, "email", @poll)
      end
    end

    private

      def projekt_subscribers
        if @poll.projekt_phase.blank?
          User.none
        else
          @poll.projekt_phase.projekt.actual_subscribers
        end
      end
  end
end
