module NotificationServices
  class NewProjektLivestreamNotifier < ApplicationService
    def initialize(projekt_livestream_id)
      @projekt_livestream = ProjektLivestream.find(projekt_livestream_id)
    end

    def call
      projekt_subscribers.find_each do |user|
        NotificationServiceMailer.new_projekt_livestream(user.id, @projekt_livestream.id).deliver_later
        Notification.add(user, @projekt_livestream)
        Activity.log(user, "email", @projekt_livestream)
      end
    end

    private

      def projekt_subscribers
        @projekt_livestream.projekt_phase.projekt.actual_subscribers
      end
  end
end
