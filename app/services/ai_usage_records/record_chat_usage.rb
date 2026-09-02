class AiUsageRecords::RecordChatUsage < ApplicationService
  def initialize(message:, feature:, provider:, requested_model:)
    @message = message
    @feature = feature
    @provider = provider
    @requested_model = requested_model
  end

  def call
    record_snapshot = AiUsageRecords::Upsert.call(
      period_month: AiUsageRecord.current_period_month,
      feature: AiUsageRecord.known_feature(@feature),
      provider: @provider.to_s,
      model: billed_model,
      counters: counters
    )

    push(record_snapshot)

    record_snapshot
  end

  private

    def push(record_snapshot)
      return if record_snapshot.blank?

      AiUsageRecords::PushRecordJob.perform_later(record_snapshot)
    rescue => e
      Rails.logger.error("[AiUsageRecord] Failed to enqueue push for #{@feature}: #{e.message}")
    end

    def counters
      tokens = @message.tokens

      {
        request_count: 1,
        unpriced_request_count: cost_total.nil? ? 1 : 0,
        input_tokens: tokens&.input.to_i,
        output_tokens: tokens&.output.to_i,
        cache_read_tokens: tokens&.cache_read.to_i,
        cache_write_tokens: tokens&.cache_write.to_i,
        thinking_tokens: tokens&.thinking.to_i,
        cost_total: cost_total || 0
      }
    end

    def cost_total
      return @cost_total if defined?(@cost_total)

      @cost_total = @message.cost.total
    rescue StandardError
      @cost_total = nil
    end

    def billed_model
      @message.model_id.presence || @requested_model.to_s
    end
end
