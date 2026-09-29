require "faraday"
require "faraday/multipart"

# The app's own client for the two OpenAI endpoints the WhatsApp assistant
# needs: the Responses API and audio transcription. It exists instead of the
# official openai gem because every released version of that gem requires
# Ruby >= 3.2.0 and this app runs 3.1.4.
#
# Faraday and faraday-multipart are not declared in the Gemfile: they arrive
# with ruby_llm, which is pinned to an exact version, so the transport under
# this client cannot move without that pin moving first.
#
# Credentials are not read here — OpenaiApi::ClientFactory injects them, so
# the key and the endpoint stay readable from one place and a caller can be
# pointed at a different account without changing this class.
class OpenaiApi::Client
  DEFAULT_BASE_URL = "https://api.openai.com/v1".freeze
  JSON_CONTENT_TYPE = "application/json".freeze

  # Bounds only the reach for a socket. Nothing bounds the wait for an answer by
  # default: how long a model may take is the caller's judgement, passed per
  # request, because a routing turn and a transcription do not deserve the same
  # patience.
  OPEN_TIMEOUT = 10

  # Nothing retries. A turn is answered while the citizen waits and holds the
  # conversation's advisory lock for as long as it runs, so silent extra
  # attempts would spend a multiple of the clock the timeout was picked to
  # bound. Retrying is the caller's decision on this path.
  def initialize(api_key:, base_url: nil, proxy: nil)
    @api_key = api_key
    @base_url = base_url.presence || DEFAULT_BASE_URL
    @proxy = proxy.presence
  end

  def responses
    @responses ||= ::OpenaiApi::Resources::Responses.new(self)
  end

  def audio
    @audio ||= ::OpenaiApi::Resources::Audio.new(self)
  end

  def post_json(path, body:, timeout: nil)
    perform(path, timeout: timeout) do |request|
      request.headers[:content_type] = JSON_CONTENT_TYPE
      request.body = ::JSON.generate(body)
    end
  end

  # The body is handed over as a hash holding a Faraday::Multipart::FilePart:
  # the multipart middleware encodes it and writes the boundary, which is the
  # one thing about this request that is not worth hand-rolling.
  def post_multipart(path, body:, timeout: nil)
    perform(path, timeout: timeout) { |request| request.body = body }
  end

  private

    def perform(path, timeout:)
      response = connection.post(url_for(path)) do |request|
        if timeout.present?
          request.options.timeout = timeout
        end

        yield request
      end

      guard_failure!(response)

      parsed(path, response.body)
    rescue ::Faraday::Error => e
      raise ::OpenaiApi::Error, "#{path} could not be reached: #{e.message}"
    end

    # A proxied box sends everything outbound through the web server's proxy,
    # and ruby_llm is handed that proxy explicitly for every provider. Faraday
    # takes it here, so this transport reaches the provider on those boxes
    # rather than having to refuse the call.
    def connection
      @connection ||= ::Faraday.new(**connection_options) do |builder|
        builder.request :multipart
        builder.adapter ::Faraday.default_adapter
      end
    end

    def connection_options
      connection_options = {
        headers: { "Authorization" => "Bearer #{@api_key}" },
        request: { open_timeout: OPEN_TIMEOUT }
      }

      if @proxy.present?
        connection_options[:proxy] = @proxy
      end

      connection_options
    end

    # Built by hand rather than left to Faraday's relative-path joining, which
    # drops the last segment of a base URL that has no trailing slash — and
    # the segment at risk is the API version.
    def url_for(path)
      "#{@base_url.chomp("/")}/#{path.delete_prefix("/")}"
    end

    def guard_failure!(response)
      return if response.success?

      raise ::OpenaiApi::Error.new(
        "#{response.status} from openai: #{failure_message(response.body)}",
        status: response.status,
        body: response.body
      )
    end

    # The provider describes a refusal under `error`, and that message is the
    # whole value of the Sentry report this becomes. An unparseable body is
    # reported as itself, truncated, because whatever is in it is the clue.
    def failure_message(body)
      ::JSON.parse(body.to_s).dig("error", "message").presence || truncated(body)
    rescue ::JSON::ParserError
      truncated(body)
    end

    def truncated(body)
      body.to_s.truncate(500)
    end

    def parsed(path, body)
      ::JSON.parse(body.to_s)
    rescue ::JSON::ParserError => e
      raise ::OpenaiApi::Error, "#{path} answered with something that is not JSON: #{e.message}"
    end
end
