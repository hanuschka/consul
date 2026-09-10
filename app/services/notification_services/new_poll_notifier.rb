module NotificationServices
  class NewPollNotifier < ApplicationService
    def initialize(poll_id)
      @poll = Poll.find(poll_id)
    end

    def call
      NotificationServices::NotifySubscribers.call(
        users: users_to_notify,
        mailer_action: "new_poll",
        mailer_record: @poll,
        notifiable: @poll,
        actionable: @poll
      )
    end

    private

      def users_to_notify
        projekt_subscribers.uniq(&:id).reject(&:not_actual?)
      end

      def projekt_subscribers
        return [] if @poll.projekt_phase.blank?

        @poll.projekt_phase.projekt.subscribers.to_a
      end
  end
end
