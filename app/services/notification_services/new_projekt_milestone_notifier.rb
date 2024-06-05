module NotificationServices
  class NewProjektMilestoneNotifier < ApplicationService
    def initialize(projekt_milestone_id)
      @projekt_milestone = Milestone.find(projekt_milestone_id)
      @projekt_phase = @projekt_milestone.milestoneable
    end

    def call
      users_to_notify.each do |user|
        NotificationServiceMailer.new_projekt_milestone(user.id, @projekt_milestone.id).deliver_later
        Notification.add(user, @projekt_phase)
        Activity.log(user, "email", @projekt_milestone)
      end
    end

    private

      def users_to_notify
        [projekt_phase_subscribers]
          .flatten.uniq(&:id)
      end

      def projekt_phase_subscribers
        if @projekt_milestone.milestoneable.is_a?(ProjektPhase::MilestonePhase)
          @projekt_milestone.milestoneable.subscribers.to_a
        else
          []
        end
      end
  end
end
