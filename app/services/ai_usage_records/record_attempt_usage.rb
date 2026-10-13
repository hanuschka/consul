class AiUsageRecords::RecordAttemptUsage < ApplicationService
  FAILED_STATUSES = %i[failed cancelled].freeze

  # One physical request to a provider, whichever operation sent it — a chat
  # completion, an embedding, a transcription. A failed attempt is counted apart
  # from request_count so cost per request stays comparable across months, but
  # whatever tokens and cost it is known to have spent are still booked: a
  # request that timed out after the provider started generating was billed.
  def initialize(feature:, provider:, model:, status:, tokens:, cost:)
    @feature = feature
    @provider = provider
    @model = model
    @status = status.to_sym
    @tokens = tokens
    @cost = cost
  end

  def call
    record_snapshot = AiUsageRecords::Upsert.call(
      period_month: AiUsageRecord.current_period_month,
      feature: AiUsageRecord.known_feature(@feature),
      provider: @provider.to_s,
      model: @model.to_s,
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
      { **request_counters, **token_counters, **cost_counters }
    end

    # Unpriced means a model the registry has no price for, which only a reply
    # can tell: a failed attempt has an unknown cost because its usage is
    # unknown, not because its model is.
    def request_counters
      return { failed_request_count: 1 } if failed?

      {
        request_count: 1,
        unpriced_request_count: cost_counters.empty? ? 1 : 0
      }
    end

    def token_counters
      {
        input_tokens: @tokens&.input.to_i,
        output_tokens: @tokens&.output.to_i,
        cache_read_tokens: @tokens&.cache_read.to_i,
        cache_write_tokens: @tokens&.cache_write.to_i,
        thinking_tokens: @tokens&.thinking.to_i
      }
    end

    def cost_counters
      return @cost_counters if defined?(@cost_counters)

      @cost_counters = AiUsageRecord.cost_counters(@cost)
    rescue StandardError
      @cost_counters = {}
    end

    def failed?
      FAILED_STATUSES.include?(@status)
    end
end
