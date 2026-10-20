class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # A worker booted before the WhatsApp credentials were added. Delayed Job's
  # own three attempts are spent within half a minute, so the retry is
  # ActiveJob's: about four hours in all, long enough for the admin page's
  # stale-worker alert to get the worker restarted.
  retry_on ::Whatsapp::MissingCredentialsError, wait: :exponentially_longer, attempts: 10

  # Per-job cap on delayed_job's run time, carried in the payload for the
  # JobWrapper patch in config/initializers/delayed_job_config.rb. nil keeps
  # the worker-wide Delayed::Worker.max_run_time.
  class_attribute :max_run_time, instance_accessor: false

  def serialize
    return super if self.class.max_run_time.blank?

    super.merge("max_run_time" => self.class.max_run_time.to_i)
  end
end
