module NotificationServices
  class NewBudgetInvestmentNotifier < ApplicationService
    def initialize(investment_id)
      @investment = Budget::Investment.find(investment_id)
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_budget_investment(user.id, @investment.id).deliver_later
        Notification.add(user, @investment)
        Activity.log(user, "email", @investment)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id).reject { |user| user.id == @investment.author.id }
      end

      def projekt_phase_subscribers
        return [] unless @investment.projekt_phase.present?

        @investment.projekt_phase.subscribers.to_a
      end
  end
end
