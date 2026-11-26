class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # A worker booted before the WhatsApp credentials were added. Delayed Job's
  # own three attempts are spent within half a minute, so the retry is
  # ActiveJob's: about four hours in all, long enough for the admin page's
  # stale-worker alert to get the worker restarted.
  retry_on ::Whatsapp::MissingCredentialsError, wait: :polynomially_longer, attempts: 10

  # Per-job caps on delayed_job's run time and attempts, carried in the payload
  # for the JobWrapper patch in config/initializers/delayed_job_config.rb. nil
  # keeps the worker-wide Delayed::Worker.max_run_time / max_attempts.
  class_attribute :max_run_time, instance_accessor: false
  class_attribute :max_attempts, instance_accessor: false

  def serialize
    super.merge(delayed_job_limits)
  end

  private

    def delayed_job_limits
      {
        "max_run_time" => self.class.max_run_time&.to_i,
        "max_attempts" => self.class.max_attempts
      }.compact
    end
end
