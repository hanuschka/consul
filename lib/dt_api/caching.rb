module DtApi::Caching
  module_function

  def update_cache_if_different(cache_key, response)
    cached_data = Rails.cache.read(cache_key)
    new_data = response.parsed_response

    if cached_data != new_data
      Rails.cache.write(cache_key, new_data, expires_in: 5.months)
    end
  end

  def cached_response_or_raise(cache_key, error)
    cached_data = Rails.cache.read(cache_key)

    if cached_data
      cached_data
    else
      error_message =
        if error.respond_to?(:code)
          "DT API error: #{error.code} for #{cache_key} and no cached version available"
        else
          "DT API connection error: #{error.class} for #{cache_key} and no cached version available"
        end

      raise error_message
    end
  end

  def build_cache_key(url, query)
    key = "dt_api#{url}"
    key += "?#{URI.encode_www_form(query)}" if query.present?
    key
  end
end
