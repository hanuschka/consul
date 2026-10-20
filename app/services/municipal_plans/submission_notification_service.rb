module MunicipalPlans
  # Handing a Vorhaben in is a notification, not a state: the Dashboard-Administration is told by
  # mail that something is waiting, and releases it from the administration area.
  class SubmissionNotificationService < ApplicationService
    def initialize(municipal_plan)
      @municipal_plan = municipal_plan
    end

    def call
      Administrator.with_user.find_each do |administrator|
        next if administrator.email.blank?

        MunicipalPlanMailer.submitted_for_release(municipal_plan, administrator).deliver_later
      end
    end

    private

      attr_reader :municipal_plan
  end
end
