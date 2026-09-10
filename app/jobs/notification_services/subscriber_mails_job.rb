class NotificationServices::SubscriberMailsJob < ApplicationJob
  queue_as :default

  # Enough recipients per job that a large projekt no longer writes one job row
  # per subscriber, few enough that the sends still spread across workers.
  BATCH_SIZE = 100

  # Explicit calls rather than a method name sent to the mailer: the action
  # travels through a job payload, so only the seven mails a projekt
  # subscription delivers may ever be reached from here.
  MAILERS = {
    "new_poll" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.new_poll(user_id, record_id) },
    "new_projekt_event" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.new_projekt_event(user_id, record_id) },
    "new_projekt_livestream" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.new_projekt_livestream(user_id, record_id) },
    "new_projekt_milestone" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.new_projekt_milestone(user_id, record_id) },
    "new_projekt_notification" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.new_projekt_notification(user_id, record_id) },
    "projekt_arguments" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.projekt_arguments(user_id, record_id) },
    "projekt_questions" =>
      ->(user_id, record_id) { ::NotificationServiceMailer.projekt_questions(user_id, record_id) }
  }.freeze

  def self.enqueue_all(mailer_action, record_id, user_ids)
    user_ids.each_slice(BATCH_SIZE) do |batch|
      perform_later(mailer_action.to_s, record_id, batch)
    end
  end

  def perform(mailer_action, record_id, user_ids)
    build_mail = MAILERS[mailer_action.to_s]
    return if build_mail.blank?

    user_ids.each do |user_id|
      deliver(build_mail, user_id, record_id)
    end
  end

  private

    # A single unusable recipient must not strand the rest of the batch, so the
    # failure is reported and the loop carries on. Nothing retries that one
    # address: a retry of the whole batch would re-send to everyone before it.
    def deliver(build_mail, user_id, record_id)
      build_mail.call(user_id, record_id).deliver_now
    rescue StandardError => e
      Rails.logger.error(
        "[NotificationServices::SubscriberMailsJob] user #{user_id}: #{e.class}: #{e.message}"
      )

      if defined?(Sentry)
        Sentry.capture_exception(e, extra: { user_id: user_id, record_id: record_id })
      end
    end
end
