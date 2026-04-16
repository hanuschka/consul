class Flags::NotifyModerationJob < ApplicationJob
  queue_as :default

  def perform(flag_id)
    email = Setting["moderation.reports_notification_email"]
    return if email.blank?

    flag = Flag.find_by(id: flag_id)
    return if flag.blank?

    ModerationMailer.flag_report(flag).deliver_now
  end
end
