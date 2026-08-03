class Mitmachbox::Error < StandardError
  attr_reader :http_status, :api_code, :api_message, :details

  def initialize(message = nil, http_status: nil, api_code: nil, api_message: nil, details: nil)
    @http_status = http_status
    @api_code = api_code
    @api_message = api_message
    @details = details

    super(message || api_message || default_message)
  end

  class << self
    def from_response(response)
      envelope = parse_envelope(response)

      class_for_status(response.code).new(
        http_status: response.code,
        api_code: envelope["code"],
        api_message: envelope["message"],
        details: envelope["details"]
      )
    end

    def class_for_status(status)
      case status.to_i
      when 401 then Mitmachbox::AuthError
      when 403 then Mitmachbox::ForbiddenError
      when 404 then Mitmachbox::NotFoundError
      when 409 then Mitmachbox::ConflictError
      when 422 then Mitmachbox::ValidationError
      else Mitmachbox::ApiError
      end
    end

    def parse_envelope(response)
      parsed = response.parsed_response
      parsed.is_a?(Hash) ? parsed : {}
    rescue StandardError
      {}
    end
  end

  private

    def default_message
      if http_status.present?
        "Mitmachbox API error (HTTP #{http_status})"
      else
        "Mitmachbox API error"
      end
    end
end

class Mitmachbox::ConnectionError < Mitmachbox::Error; end
class Mitmachbox::AuthError < Mitmachbox::Error; end
class Mitmachbox::ForbiddenError < Mitmachbox::Error; end
class Mitmachbox::NotFoundError < Mitmachbox::Error; end
class Mitmachbox::ConflictError < Mitmachbox::Error; end
class Mitmachbox::ValidationError < Mitmachbox::Error; end
class Mitmachbox::ApiError < Mitmachbox::Error; end
