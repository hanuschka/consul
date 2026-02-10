# DT API caching layer with fallback behavior and error reporting to Sentry
#
# Provides resilient access to DT API resources (consul_ai_prompts,
# content_block_templates, etc) by caching successful responses and using them
# as fallback when the API fails. Ensures the application continues functioning
# during DT API outages, preventing user-facing failures.
#
# Behavior:
# - Success (2xx): Updates cache if data differs, returns parsed response (cache: 5 months)
# - Error (non-2xx): Logs to Rails.logger.error, reports to Sentry, returns cached data or raises exception
# - Timeout/Connection: Logs to Rails.logger.error, reports to Sentry, returns cached data or raises exception
#
# All errors logged and reported to Sentry include: cache key, endpoint URL, status/error details
# Sentry reports use fingerprinting to prevent duplicate error flooding during prolonged outages
#
# Usage:
#   data = DtApi::Caching.get_with_cache("dt_api/consul_ai_prompts/codename/resource_type") do
#     DtApi::Client.new.consul_ai_prompts.get(:codename, resource_type: "type")
#   end

module DtApi::Caching
  module_function

  def get_with_cache(cache_key)
    response = yield

    if response.success?
      update_cache_if_different(cache_key, response)
      response.parsed_response
    else
      log_and_report_error(cache_key, response)
      use_cached_or_raise(cache_key, response)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    log_and_report_exception(cache_key, e)
    use_cached_or_raise(cache_key, e)
  end

  def update_cache_if_different(cache_key, response)
    cached_data = Rails.cache.read(cache_key)
    new_data = response.parsed_response

    if cached_data != new_data
      Rails.cache.write(cache_key, new_data, expires_in: 5.months)
    end
  end

  def use_cached_or_raise(cache_key, error)
    cached_data = Rails.cache.read(cache_key)

    if cached_data
      cached_data
    else
      error_message = if error.respond_to?(:code)
        "DT API error: #{error.code} for #{cache_key} and no cached version available"
      else
        "DT API connection error: #{error.class} for #{cache_key} and no cached version available"
      end

      raise error_message
    end
  end

  def log_and_report_error(cache_key, response)
    endpoint = response.request.uri.to_s

    Rails.logger.error(
      "[DtApi::Caching] API error: #{response.code} for #{endpoint} (cache_key: #{cache_key})"
    )

    Sentry.capture_message(
      "DT API Error",
      level: :error,
      fingerprint: ["dt-api-error", cache_key],
      extra: {
        cache_key: cache_key,
        status_code: response.code,
        response_body: response.body,
        endpoint: endpoint
      }
    )
  end

  def log_and_report_exception(cache_key, exception)
    endpoint = extract_endpoint_from_cache_key(cache_key)

    Rails.logger.error(
      "[DtApi::Caching] Connection error: #{exception.class} for #{endpoint} (cache_key: #{cache_key})"
    )

    Sentry.capture_exception(
      exception,
      fingerprint: ["dt-api-connection-error", cache_key],
      extra: {
        cache_key: cache_key,
        endpoint: endpoint,
        error_type: "connection_error"
      }
    )
  end

  def extract_endpoint_from_cache_key(cache_key)
    cache_key.gsub("dt_api/", "")
  end
end
