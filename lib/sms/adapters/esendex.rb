class Sms::Adapters::Esendex
  include HTTParty

  open_timeout 5
  read_timeout 5

  DEFAULT_BASE_URL = "https://api.esendex.de".freeze
  VALIDITY = 15.minutes
  RESCUED_ERRORS = [
    HTTParty::Error,
    JSON::ParserError,
    Timeout::Error,
    EOFError,
    SocketError,
    SystemCallError,
    OpenSSL::SSL::SSLError
  ].freeze

  def initialize(config)
    @sender = config[:sender]
    @settings = (config[:esendex] || {}).to_h.with_indifferent_access
  end

  def deliver(to:, text:)
    if @settings[:api_key].blank? || @settings[:account_reference].blank?
      return Sms::Result.failure("Esendex api_key or account_reference missing")
    end

    response = Sms::Adapters::Esendex.post("#{base_url}/v2/messages", headers: headers, body: payload(to, text).to_json)

    if response.success?
      Sms::Result.success(message_id: response_data(response).dig("data", "messageIds", 0))
    else
      Sms::Result.failure("HTTP #{response.code} #{error_codes(response)}".strip)
    end
  rescue *RESCUED_ERRORS => e
    Sms::Result.failure(e.class.name)
  end

  private

    def base_url
      @settings[:base_url].presence || DEFAULT_BASE_URL
    end

    def headers
      { "X-Api-Key" => @settings[:api_key], "Content-Type" => "application/json" }
    end

    def payload(to, text)
      {
        accountReference: @settings[:account_reference],
        channel: "SMS",
        from: @sender.presence,
        characterSet: "Auto",
        messageType: "AuthenticationAndSecurity",
        validity: VALIDITY.from_now.utc.iso8601(3),
        body: { text: text },
        recipients: [{ msisdn: to }]
      }.compact
    end

    def response_data(response)
      data = response.parsed_response
      data.is_a?(Hash) ? data : {}
    end

    def error_codes(response)
      Array(response_data(response)["errors"]).filter_map { |error| error["errorCode"] if error.is_a?(Hash) }.join(", ")
    end
end
