module NotificationServices
  class MemoNotifier < ApplicationService
    def initialize(memo_id)
      @memo = Memo.find(memo_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.memo(@memo.id, user.id, namespace(user, @memo)).deliver_later
        Notification.add(user, @memo)
        Activity.log(user, "email", @memo)
      end

      @memo.update!(last_notification_sent_at: Time.zone.now)
    end

    private

      def users_to_notify
        [administrators, projekt_managers, deficiency_report_managers, deficiency_report_officers]
          .flatten.uniq(&:id).reject { |user| user.id == @memo.user_id }
      end

      def administrators
        User.joins(:administrator).to_a
      end

      def projekt_managers
        return Array.new unless @memo.root_memoable.respond_to?(:projekt_phase)

        User.joins(projekt_manager: :projekts)
          .where(projekt_managers: { projekts: { id: @memo.root_memoable.projekt_phase.projekt.id }}).to_a
      end

      def deficiency_report_managers
        return Array.new unless @memo.root_memoable.is_a?(DeficiencyReport)

        User.joins(:deficiency_report_manager)
      end

      def deficiency_report_officers
        return Array.new unless @memo.root_memoable.is_a?(DeficiencyReport)

        User.joins(:deficiency_report_officer).where(
          deficiency_report_officers: { id: @memo.root_memoable.responsible_officers.pluck(:id) }
        )
      end

      def namespace(user, memo)
        return :deficiency_report_management if memo.root_memoable.is_a?(DeficiencyReport)

        if user.administrator?
          :admin
        elsif user.projekt_manager?
          :projekt_management
        end
      end
  end
end
