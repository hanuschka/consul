class AiUsageRecords::PushCurrentMonths < ApplicationService
  PUSHED_COLUMNS = AiUsageRecords::Upsert::RETURNED_COLUMNS

  def call
    return if !Dt.connected?

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
