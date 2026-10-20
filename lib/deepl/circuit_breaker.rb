require_dependency "deepl/error"

module Deepl
  module CircuitBreaker
    module_function

    FALLBACK_CACHE = ActiveSupport::Cache::MemoryStore.new
    FAILURE_KEY = "deepl:circuit:failures".freeze
    OPEN_KEY = "deepl:circuit:open".freeze
    FAILURE_THRESHOLD = 5
    FAILURE_WINDOW = 5.minutes
    OPEN_DURATION = 10.minutes

    def guard!(context)
      return unless open?

      raise Deepl::CircuitOpenError,
        "DeepL circuit is open after #{FAILURE_THRESHOLD} consecutive failures (context: #{context})"
    end

    def open?
      cache.read(OPEN_KEY).present?
    end

    def record_success
      cache.delete(FAILURE_KEY)
      cache.delete(OPEN_KEY)
    end

    def record_failure
      return if increment_failures < FAILURE_THRESHOLD

      Rails.logger.error("[DeepL] Circuit opened for #{OPEN_DURATION.inspect}")
      cache.write(OPEN_KEY, true, expires_in: OPEN_DURATION)
      cache.delete(FAILURE_KEY)
    end

    def reset!
      record_success
    end

    def increment_failures
      count = cache.increment(FAILURE_KEY, 1, expires_in: FAILURE_WINDOW)
      return count if count.present?

      cache.write(FAILURE_KEY, 1, expires_in: FAILURE_WINDOW, raw: true)
      1
    end

    def cache
      return FALLBACK_CACHE if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      Rails.cache
    end
  end
end
