module NotificationServices
  module SharedMethods
    def batch_size
      @batch_size = Rails.application.secrets.fetch(:emails_batch_size, 300).to_i
    end

    def batch_interval
      @batch_interval = Rails.application.secrets.fetch(:emails_batch_interval_in_minutes, 10).to_i.minutes
    end

    def queue_options(run_at)
      { run_at: run_at, queue: "notifications", priority: 10 }
    end
  end
end
