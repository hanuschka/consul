require_dependency "mitmachbox/error"

class Mitmachbox::Client
  include HTTParty

  open_timeout 5
  read_timeout 15

  MUTATING_VERBS = [:post, :patch, :put, :delete].freeze
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

  def initialize(acting_user: nil)
    @acting_user = acting_user
  end

  def surveys
    @surveys ||= Mitmachbox::Resources::Surveys.new(self)
  end

  def versions
    @versions ||= Mitmachbox::Resources::Versions.new(self)
  end

  def questions
    @questions ||= Mitmachbox::Resources::Questions.new(self)
  end

  def options
    @options ||= Mitmachbox::Resources::Options.new(self)
  end

  def assignments
    @assignments ||= Mitmachbox::Resources::Assignments.new(self)
  end

  def deployments
    @deployments ||= Mitmachbox::Resources::Deployments.new(self)
  end

  def results
    @results ||= Mitmachbox::Resources::Results.new(self)
  end

  def get(path, query: nil)
    perform(:get, path, query:)
  end

  def get_raw(path, query: nil)
    perform(:get, path, query:, raw: true)
  end

  def post(path, body: nil)
    perform(:post, path, body:)
  end

  def patch(path, body: nil)
    perform(:patch, path, body:)
  end

  def put(path, body: nil)
    perform(:put, path, body:)
  end

  def delete(path)
    perform(:delete, path)
  end

  private

    def perform(verb, path, query: nil, body: nil, raw: false)
      ensure_acting_user!(verb, path)

      response = execute(verb, path, query:, body:)

      if response.code == 401
        Mitmachbox::TokenProvider.invalidate!
        response = execute(verb, path, query:, body:)
      end

      handle_response(response, context: path, raw:)
    rescue *NETWORK_ERRORS => e
      Mitmachbox::ErrorReporter.report_exception(e, context: path)

      raise Mitmachbox::ConnectionError, "Mitmachbox request failed: #{e.class}"
    end

    def execute(verb, path, query:, body:)
      request_options = { headers: headers_for(verb) }
      request_options[:query] = query if query.present?
      request_options[:body] = body.to_json unless body.nil?

      self.class.public_send(verb, url_for(path), **request_options)
    end

    def handle_response(response, context:, raw:)
      if response.success?
        raw ? response.body : response.parsed_response
      else
        Mitmachbox::ErrorReporter.report_error(response, context:)

        raise Mitmachbox::Error.from_response(response)
      end
    end

    def url_for(path)
      "#{Mitmachbox.base_url}/api/manage/v1/orgs/#{Mitmachbox.org_id}#{path}"
    end

    def headers_for(verb)
      headers = {
        "Authorization" => "Bearer #{Mitmachbox::TokenProvider.access_token}",
        "Accept" => "application/json"
      }

      if mutating?(verb)
        headers["Content-Type"] = "application/json"
        headers["X-Acting-External-Id"] = @acting_user.id.to_s
        headers["X-Acting-External-Name"] = @acting_user.name if @acting_user.name.present?
        headers["X-Acting-External-Email"] = @acting_user.email if @acting_user.email.present?
      end

      headers
    end

    def mutating?(verb)
      MUTATING_VERBS.include?(verb)
    end

    def ensure_acting_user!(verb, path)
      return unless mutating?(verb)
      return if @acting_user.present?

      raise Mitmachbox::Error, "acting_user is required for mutating requests (#{verb.to_s.upcase} #{path})"
    end
end
