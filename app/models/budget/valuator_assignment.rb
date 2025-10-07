class Budget
  class ValuatorAssignment < ApplicationRecord
    belongs_to :valuator, counter_cache: :budget_investments_count
    belongs_to :investment, counter_cache: true

    after_create :notify_valuator

    private

      def notify_valuator
        Mailer.new_valuator_assignment(self).deliver_later
      end
  end
end
