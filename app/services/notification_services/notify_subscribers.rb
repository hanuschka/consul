# The three things every projekt-subscription announcement does. Doing them per
# user meant three writes and one job row per subscriber, all inside the admin's
# request.
class NotificationServices::NotifySubscribers < ApplicationService
  def initialize(users:, mailer_action:, mailer_record:, notifiable:, actionable:)
    @users = users
    @mailer_action = mailer_action
    @mailer_record = mailer_record
    @notifiable = notifiable
    @actionable = actionable
  end

  def call
    return if users.blank?

    user_ids = users.map(&:id)

    Notification.add_all(users, notifiable)
    Activity.log_all("email", actionable, user_ids)

    NotificationServices::SubscriberMailsJob.enqueue_all(mailer_action, mailer_record.id, user_ids)
  end

  private

    attr_reader :users, :mailer_action, :mailer_record, :notifiable, :actionable
end
