module NotificationServices
  class NewProjektMilestoneNotifier < ApplicationService
    def initialize(projekt_milestone_id)
      @projekt_milestone = Milestone.find(projekt_milestone_id)
      @projekt_phase = @projekt_milestone.milestoneable
    end

    def call
      NotificationServices::NotifySubscribers.call(
        users: users_to_notify,
        mailer_action: "new_projekt_milestone",
        mailer_record: @projekt_milestone,
        notifiable: @projekt_phase,
        actionable: @projekt_milestone
      )
    end

    private

      def users_to_notify
        projekt_subscribers.uniq(&:id).reject(&:not_actual?)
      end

      def projekt_subscribers
        if @projekt_milestone.milestoneable.is_a?(ProjektPhase::MilestonePhase)
          @projekt_milestone.milestoneable.projekt.subscribers.to_a
        else
          []
        end
      end
  end
end
