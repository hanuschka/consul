namespace :api_request_logs do
  desc "Deletes API request logs older than 7 months"
  task cleanup: :environment do
    deleted_count = ApiRequestLog.where("created_at < ?", 7.months.ago).delete_all
    Rails.logger.info("[ApiRequestLogs] Cleaned up #{deleted_count} old records")
  end
end
