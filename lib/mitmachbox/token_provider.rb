require_dependency "mitmachbox/error"

module Mitmachbox::TokenProvider
  module_function

  EXPIRY_MARGIN = 60
  NETWORK_ERRORS = [
    Timeout::Error,
    Net::OpenTimeout,
    Net::ReadTimeout,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    SocketError,
    OpenSSL::SSL::SSLError
  ].freeze

  def access_token
    cached_token = Rails.cache.read(cache_key)
    return cached_token if cached_token.present?

    token_data = request_token
    token = token_data["access_token"]
    expires_in = token_data["expires_in"].to_i

    if expires_in > EXPIRY_MARGIN
      Rails.cache.write(cache_key, token, expires_in: (expires_in - EXPIRY_MARGIN).seconds)
    end

    token
  end

  def invalidate!
    Rails.cache.delete(cache_key)
  end

  def cache_key
    "mitmachbox/access_token/#{Digest::SHA1.hexdigest("#{Mitmachbox.base_url}#{Mitmachbox.client_id}")}"
  end

  def request_token
    response = HTTParty.post(
      "#{Mitmachbox.base_url}/oauth/token",
      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
      body: {
        grant_type: "client_credentials",
        client_id: Mitmachbox.client_id,
        client_secret: Mitmachbox.client_secret
      },
      open_timeout: 5,
      read_timeout: 15
    )

    unless response.success?
      Mitmachbox::ErrorReporter.report_error(response, context: "oauth/token")

      raise Mitmachbox::AuthError.new(
        "Mitmachbox token request failed: #{token_error_description(response)}",
        http_status: response.code
      )
    end

    parsed = response.parsed_response
    unless parsed.is_a?(Hash) && parsed["access_token"].present?
      Mitmachbox::ErrorReporter.report_error(response, context: "oauth/token")

      raise Mitmachbox::AuthError.new(
        "Mitmachbox token request returned an unexpected response",
        http_status: response.code
      )
    end

    parsed
  rescue *NETWORK_ERRORS => e
    Mitmachbox::ErrorReporter.report_exception(e, context: "oauth/token")

    raise Mitmachbox::ConnectionError, "Mitmachbox token request failed: #{e.class}"
  end

  def token_error_description(response)
    parsed = response.parsed_response
    return "HTTP #{response.code}" unless parsed.is_a?(Hash)

    [parsed["error"], parsed["error_description"]].compact_blank.join(" - ").presence ||
      "HTTP #{response.code}"
  rescue StandardError
    "HTTP #{response.code}"
  end
end
