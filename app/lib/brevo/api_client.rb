class Brevo::ApiClient
  include HTTParty

  open_timeout 5
  read_timeout 30

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ConnectionError < Error; end

  class ResponseError < Error
    attr_reader :code

    def initialize(message, code)
      @code = code
      super(message)
    end
  end

  # Brevo caps this endpoint at 500 contacts per call. MAX_PAGES only exists so a paging bug on
  # either side cannot turn a nightly job into an endless loop; 200 pages is far above any
  # plausible member list.
  PAGE_SIZE = 500
  MAX_PAGES = 200
  MAX_ATTEMPTS = 3
  RETRYABLE_CODES = [429, 500, 502, 503, 504].freeze
  ERROR_BODY_EXCERPT = 300

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

  def initialize(api_key: Brevo::Settings.api_key)
    @api_key = api_key
  end

  # Every contact of a list, following Brevo's offset paging. Returns an array of the raw contact
  # hashes: { "id" => 42, "email" => "...", "emailBlacklisted" => false, "attributes" => {...} }.
  def contacts_in_list(list_id)
    raise ConfigurationError, "No Brevo list configured" if list_id.blank?

    contacts = []

    MAX_PAGES.times do |page|
      batch = get("/contacts/lists/#{list_id}/contacts",
                  limit: PAGE_SIZE, offset: page * PAGE_SIZE)["contacts"]

      break if batch.blank?

      contacts += batch
      break if batch.size < PAGE_SIZE
    end

    contacts
  end

  # A single contact, looked up by email or by Brevo id. Returns nil when Brevo does not know it —
  # the normal answer for a webhook that fires after the contact was deleted.
  def contact(identifier)
    return if identifier.blank?

    get("/contacts/#{CGI.escape(identifier.to_s)}")
  rescue ResponseError => e
    raise unless e.code == 404

    nil
  end

  private

    def get(path, **query)
      raise ConfigurationError, "No Brevo API key configured" if @api_key.blank?

      attempt = 0

      begin
        attempt += 1
        response = self.class.get(
          "#{Brevo::Settings::API_BASE_URI}#{path}",
          headers: { "api-key" => @api_key, "Accept" => "application/json" },
          query: query.presence
        )

        return response.parsed_response if response.success?

        raise ResponseError.new(error_message_for(path, response), response.code)
      rescue ResponseError => e
        raise unless retry?(e.code, attempt)

        sleep(2**(attempt - 1))
        retry
      rescue *NETWORK_ERRORS => e
        raise ConnectionError, "Brevo request failed (GET #{path}): #{e.class}" if attempt >= MAX_ATTEMPTS

        sleep(2**(attempt - 1))
        retry
      end
    end

    def retry?(code, attempt)
      RETRYABLE_CODES.include?(code) && attempt < MAX_ATTEMPTS
    end

    def error_message_for(path, response)
      "Brevo responded #{response.code} to GET #{path}: #{response.body.to_s.first(ERROR_BODY_EXCERPT)}"
    end
end
