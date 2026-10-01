class OpenaiApi::Resources::Responses
  PATH = "responses".freeze

  def initialize(client)
    @client = client
  end

  # `request_options` carries the per-call timeout, in the shape the official
  # SDK took it in, so the transport swap did not have to reach into the callers
  # that build it. Everything else is the request body as the Responses API
  # documents it — model, instructions, input, tools, store, reasoning,
  # previous_response_id, text — passed on unrenamed.
  def create(request_options: {}, **body)
    ::OpenaiApi::ModelResponse.new(
      @client.post_json(
        PATH,
        body: body.compact,
        timeout: request_options[:timeout]
      )
    )
  end
end
