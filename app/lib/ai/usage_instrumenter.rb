# Installed as the instrumenter of one RubyLLM context, so every event the
# calls made through it emit already knows which feature asked. ruby_llm sends
# a usage event per physical attempt — retries and failures included, which an
# after_message hook never sees — and booking it here rather than in a global
# subscriber keeps two things true on Rails 6.1: a failure to book cannot raise
# into the AI call, and the feature does not have to be smuggled through a
# thread-local.
#
# Every event still goes on to the instrumenter the context inherited
# (ActiveSupport::Notifications, set by the ruby_llm Railtie), with the feature
# added, so other subscribers keep seeing them.
class Ai::UsageInstrumenter
  USAGE_EVENT = "usage.ruby_llm".freeze

  def initialize(feature:, provider:, requested_model:, delegate:)
    @feature = feature
    @provider = provider
    @requested_model = requested_model
    @delegate = delegate
  end

  def instrument(name, payload = {}, &block)
    attributed_payload = payload.merge(feature: @feature)

    if name == USAGE_EVENT
      record_usage(attributed_payload)
    end

    if @delegate.present?
      return @delegate.instrument(name, attributed_payload, &block)
    end

    return if block.nil?

    block.call(attributed_payload)
  end

  private

    # The model an attempt names is the one it was sent to, fixed before the
    # provider answered, so a blank one can only mean the caller named none and
    # the configured model went out.
    def record_usage(payload)
      ::AiUsageRecords::RecordAttemptUsage.call(
        feature: @feature,
        provider: @provider,
        model: payload[:model].presence || @requested_model,
        status: payload[:status],
        tokens: payload[:tokens],
        cost: payload[:cost]
      )
    rescue => e
      Rails.logger.error("[AiUsageRecord] Failed to record usage for #{@feature}: #{e.message}")
    end
end
