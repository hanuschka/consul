# DT API caching layer with fallback behavior and error reporting to Sentry
#
# Provides resilient access to DT API resources (consul_ai_prompts,
# content_block_templates, etc) by caching successful responses and using them
# as fallback when the API fails. Ensures the application continues functioning
# during DT API outages, preventing user-facing failures.
#
# Behavior:
# - Success (2xx): Updates cache if data differs, returns parsed response (cache: 5 months)
# - Error (4xx/5xx): Reports to Sentry, returns cached data or calls error_callback
# - Timeout/Connection: Reports to Sentry, returns cached data or calls error_callback
#
# All errors reported to Sentry include: cache key, endpoint URL, status/error details
#
# Usage:
#   data = DtApi::Caching.get_with_cache(
#     "dt_api/consul_ai_prompts/codename/resource_type",
#     error_callback: -> { raise "Failed to fetch and no cache available" }
#   ) { DtApi::Client.new.consul_ai_prompts.get(:codename, resource_type: "type") }

module DtApi::Caching
  module_function

  def get_with_cache(cache_key, error_callback: -> {})
    response = yield

    if response.success?
      update_cache_if_different(cache_key, response)
      response.parsed_response
    elsif response.code >= 400 && response.code < 600
      report_error_to_sentry(cache_key, response)
      use_cached_or_error(cache_key, error_callback)
    else
      response.parsed_response
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    report_exception_to_sentry(cache_key, e)
    use_cached_or_error(cache_key, error_callback)
  end

  def update_cache_if_different(cache_key, response)
    cached_data = Rails.cache.read(cache_key)
    new_data = response.parsed_response

    if cached_data != new_data
      Rails.cache.write(cache_key, new_data, expires_in: 5.months)
    end
  end

  def use_cached_or_error(cache_key, error_callback)
    cached_data = Rails.cache.read(cache_key)

    if cached_data
      cached_data
    else
      error_callback.call
    end
  end

  def report_error_to_sentry(cache_key, response)
    Sentry.capture_message(
      "DT API Error",
      level: :error,
      extra: {
        cache_key: cache_key,
        status_code: response.code,
        response_body: response.body,
        endpoint: response.request.uri.to_s
      }
    )
  end

  def report_exception_to_sentry(cache_key, exception)
    Sentry.capture_exception(
      exception,
      extra: {
        cache_key: cache_key,
        endpoint: extract_endpoint_from_cache_key(cache_key),
        error_type: "connection_error"
      }
    )
  end

  def extract_endpoint_from_cache_key(cache_key)
    cache_key.gsub("dt_api/", "")
  end
end
