class AiUsageRecords::RecordEmbeddingUsage < ApplicationService
  def initialize(embedding:, feature:, provider:, requested_model:)
    @embedding = embedding
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

    # The embeddings endpoint bills input tokens only and reports no price, so
    # the request lands in the unpriced bucket like any other uncosted call.
    def counters
      {
        request_count: 1,
        unpriced_request_count: 1,
        input_tokens: @embedding.input_tokens.to_i,
        cost_total: 0
      }
    end

    def billed_model
      @embedding.model.presence || @requested_model.to_s
    end
end
