module NotificationServices
  class NewProjektLivestreamNotifier < ApplicationService
    def initialize(projekt_livestream_id)
      @projekt_livestream = ProjektLivestream.find(projekt_livestream_id)
    end

    def call
      NotificationServices::NotifySubscribers.call(
        users: users_to_notify,
        mailer_action: "new_projekt_livestream",
        mailer_record: @projekt_livestream,
        notifiable: @projekt_livestream,
        actionable: @projekt_livestream
      )
    end

    private

      def users_to_notify
        projekt_subscribers.uniq(&:id).reject(&:not_actual?)
      end

      def projekt_subscribers
        @projekt_livestream.projekt_phase.projekt.subscribers.to_a
      end
  end
end
