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
Delayed::Worker.max_attempts = 3
Delayed::Worker.max_run_time = 1500.minutes
Delayed::Worker.read_ahead = 10
Delayed::Worker.default_queue_name = "default"
Delayed::Worker.raise_signal_exceptions = :term
Delayed::Worker.logger = Logger.new(File.join(Rails.root, "log", "delayed_job.log"))

# Delayed::Job only calls its own #reload! from the idle branch of the work
# loop -- between polls, and never around the job it is about to run. A worker
# that keeps finding work therefore executes whatever the files held when it
# booted, for the life of the process, and reloading outside the executor
# leaves half-unloaded constants behind when it does happen.
#
# Wrapping every job in the reloader is what a request already does: check for
# changed files, reload if there are any, run the job against the code on disk.
class DelayedJobReloaderPlugin < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.around(:perform) do |worker, job, *args, &block|
      Rails.application.reloader.wrap { block.call(worker, job, *args) }
    end
  end
end

Delayed::Worker.plugins << DelayedJobReloaderPlugin if Rails.env.development?
