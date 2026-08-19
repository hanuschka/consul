module Ai::OpenaiSdk::Responses
  # One name for every structured answer on this transport. The provider wants a
  # name for the schema and nothing reads it back, so a per-caller one would only
  # be a second thing to keep in step with the schema itself.
  SCHEMA_NAME = "output".freeze

  # Everything the assistant asks for is one turn of a conversation somebody is
  # waiting on, so nothing here streams and nothing runs in the background.
  # Usage is recorded off every response, including the intermediate ones a tool
  # loop spends — each is a billed request.
  def self.create(feature:, requested_model:, timeout_seconds: nil, **params)
    response =
      ::Ai::OpenaiSdk::Client
        .build
        .responses
        .create(
          **params.compact,
          **::Ai::OpenaiSdk::Client.request_options(timeout_seconds)
        )

    ::Ai::OpenaiSdk::Usage.record(
      response: response, feature: feature, requested_model: requested_model
    )

    response
  end

  # Not stored: a single-shot judgement has no next turn to chain to, so asking
  # the provider to keep it would retain a citizen's words for thirty days and
  # buy nothing.
  def self.json(schema:, instructions:, input:, model:, feature:, timeout_seconds: nil)
    response = create(
      feature: feature,
      requested_model: model,
      timeout_seconds: timeout_seconds,
      model: model,
      instructions: instructions,
      input: input,
      store: false,
      text: json_format(schema)
    )

    parsed(response.output_text)
  end

  def self.text(instructions:, input:, model:, feature:, timeout_seconds: nil)
    response = create(
      feature: feature,
      requested_model: model,
      timeout_seconds: timeout_seconds,
      model: model,
      instructions: instructions,
      input: input,
      store: false
    )

    response.output_text.to_s
  end

  # Sent strict, because the schemas these callers hand over already satisfy it:
  # every property is listed in `required`, every object is closed, and an
  # optional value is a nullable type rather than a missing key. ruby_llm sent
  # them strict as well, so the shape the model is held to does not change with
  # the transport.
  def self.json_format(schema)
    {
      format: {
        type: "json_schema",
        name: SCHEMA_NAME,
        schema: schema,
        strict: true
      }
    }
  end

  # An answer that is not the JSON it was told to produce is a failure of the
  # call, not of the caller: handing back an empty hash lets each service fall
  # through its own "the model said nothing usable" path, which every one of them
  # already has.
  def self.parsed(output_text)
    JSON.parse(output_text.to_s)
  rescue JSON::ParserError => e
    Rails.logger.error("[Ai::OpenaiSdk] structured answer was not JSON: #{e.message}")

    {}
  end
end
