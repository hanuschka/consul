if Rails.env.test?
  Delayed::Worker.delay_jobs = false
elsif Rails.env.development?
  Delayed::Worker.delay_jobs = true
elsif Rails.application.secrets.delay_jobs.nil?
  Delayed::Worker.delay_jobs = true
else
  Delayed::Worker.delay_jobs = Rails.application.secrets.delay_jobs
end

Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.sleep_delay = 2
Delayed::Worker.max_attempts = 4
Delayed::Worker.max_run_time = 1500.minutes
Delayed::Worker.read_ahead = 10
Delayed::Worker.default_queue_name = "default"
Delayed::Worker.raise_signal_exceptions = :term
Delayed::Worker.logger = Logger.new(File.join(Rails.root, "log", "delayed_job.log"))

if Rails.env.development?
  Delayed::Worker.class_eval do
    def reload!
      return if !self.class.reload_app?
      return if !Rails.application.reloader.check!

      Rails.application.reloader.reload!
    end
  end
end
