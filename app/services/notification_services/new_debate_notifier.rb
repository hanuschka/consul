module NotificationServices
  class NewDebateNotifier < ApplicationService
    def initialize(debate_id)
      @debate = Debate.find(debate_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_debate(user.id, @debate.id).deliver_later
        Notification.add(user, @debate)
        Activity.log(user, "email", @debate)
      end
    end

    private

      def users_to_notify
        [administrators, moderators, projekt_managers, projekt_phase_subscribers]
          .flatten.uniq(&:id).reject { |user| user.id == @debate.author_id }
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_debate: true).to_a
      end

      def moderators
        User.joins(:moderator).where(adm_email_on_new_debate: true).to_a
      end

      def projekt_managers
        User.joins(projekt_manager: :projekt_manager_assignments)
          .where(adm_email_on_new_debate: true)
          .where(projekt_manager_assignments: { projekt_id: @debate.projekt_phase.projekt.id })
          .where("projekt_manager_assignments.permissions @> ARRAY[?]::text[]", ["get_notifications"]).to_a
      end

      def projekt_phase_subscribers
        return [] unless @debate.projekt_phase.present?

        @debate.projekt_phase.subscribers.to_a
      end
  end
end
