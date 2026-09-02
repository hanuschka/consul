class AiUsageRecords::PushRecordJob < ApplicationJob
  queue_as :default

  def perform(record_snapshot)
    return if record_snapshot.blank?
    return unless Dt.connected?

    DtApi::Client.new.consul_ai_usage_records.create_batch([record_snapshot])
  rescue => e
    Rails.logger.error("[AiUsageRecord] Failed to push record to DT: #{e.message}")
  end
end
