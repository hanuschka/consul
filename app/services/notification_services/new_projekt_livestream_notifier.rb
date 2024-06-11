module NotificationServices
  class NewProjektLivestreamNotifier < ApplicationService
    def initialize(projekt_livestream_id)
      @projekt_livestream = ProjektLivestream.find(projekt_livestream_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_projekt_livestream(user.id, @projekt_livestream.id).deliver_later
        Notification.add(user, @projekt_livestream)
        Activity.log(user, "email", @projekt_livestream)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id)
      end

      def projekt_phase_subscribers
        @projekt_livestream.projekt_phase.subscribers.to_a
      end
  end
end
