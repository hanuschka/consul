module NotificationServices
  class NewProjektNotifier < ApplicationService
    def initialize(projekt)
      @projekt = projekt
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_projekt(user.id, @projekt.id).deliver_later
        Notification.add(user, @projekt)
        Activity.log(user, "email", @projekt)
      end
    end

    private

      def users_to_notify
        [projekt_reviewers].flatten.uniq(&:id)
      end

      def projekt_reviewers
        User.joins(projekt_manager: :projekt_manager_assignments)
            .where("projekt_manager_assignments.permissions @> ARRAY[?]::text[]", ["review"]).to_a
      end
  end
end
