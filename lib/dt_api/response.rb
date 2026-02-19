class DtApi::Response
  extend Forwardable

  def_delegators :@response, :code, :headers, :body, :message, :request, :[], :dig

  def initialize(response, cached_response: nil)
    @response = response
    @cached_response = cached_response
  end

  def success?
    @response&.success? || false
  end

  def parsed_response
    @cached_response.presence || @response.parsed_response
  end
end
