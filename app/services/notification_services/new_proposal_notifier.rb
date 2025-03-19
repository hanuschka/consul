module NotificationServices
  class NewProposalNotifier < ApplicationService
    def initialize(proposal_id)
      @proposal = Proposal.find(proposal_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_proposal(user.id, @proposal.id).deliver_later
        Notification.add(user, @proposal)
        Activity.log(user, "email", @proposal)
      end
    end

    private

      def users_to_notify
        [administrators, moderators, projekt_managers, projekt_phase_subscribers]
          .flatten.uniq(&:id).reject { |user| user.id == @proposal.author.id }
      end

      def administrators
        User.joins(:administrator).where(adm_email_on_new_proposal: true).to_a
      end

      def moderators
        User.joins(:moderator).where(adm_email_on_new_proposal: true).to_a
      end

      def projekt_managers
        User.joins(projekt_manager: :projekt_manager_assignments)
          .where(adm_email_on_new_proposal: true)
          .where(projekt_manager_assignments: { projekt_id: @proposal.projekt_phase.projekt.id })
          .where("projekt_manager_assignments.permissions @> ARRAY[?]::text[]", ["get_notifications"]).to_a
      end

      def projekt_phase_subscribers
        return [] unless @proposal.projekt_phase.present?

        @proposal.projekt_phase.subscribers.to_a
      end
  end
end
