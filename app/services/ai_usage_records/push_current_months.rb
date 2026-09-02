class AiUsageRecords::PushCurrentMonths < ApplicationService
  PUSHED_COLUMNS = %w[
    period_month feature provider model version
    request_count unpriced_request_count
    input_tokens output_tokens cache_read_tokens cache_write_tokens
    thinking_tokens audio_seconds cost_total
  ].freeze

  def call
    return unless Dt.connected?

    records = pushable_records

    return if records.empty?

    DtApi::Client.new.consul_ai_usage_records.create_batch(records)
  rescue => e
    Rails.logger.error("[AiUsageRecord] Failed to push usage to DT: #{e.message}")
  end

  private

    def pushable_records
      AiUsageRecord
        .since(AiUsageRecord.period_month_for(1.month.ago))
        .order(:period_month, :feature)
        .map { |record| record.attributes.slice(*PUSHED_COLUMNS) }
    end
end
