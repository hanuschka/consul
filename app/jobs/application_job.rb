class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Globalize keeps its fallbacks in RequestStore, which is cleared at the end
  # of every request and of every reloader-wrapped job, so the boot-time value
  # from config/application.rb does not survive into a worker's second job.
  # Without them a record translated only in :de reads back nil under any other
  # locale. Controllers re-establish them per request in GlobalizeFallbacks;
  # this is the same guarantee for jobs.
  before_perform { Globalize.set_fallbacks_to_all_available_locales }
end
