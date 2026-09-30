# A schema-bound request that gets one second chance when the model answers
# with something other than a JSON object, re-asking with an instruction to
# stick to the schema. A request that raised never produced an answer to
# correct — the provider was unreachable or refused it — so it is not retried,
# and request_failed? lets the caller tell the admin which of the two it was.
class Ai::CorrectiveJsonRequest
  RETRY_INSTRUCTION =
    "Your previous response was not valid JSON matching the schema. " \
    "Please respond again with ONLY a JSON object matching the schema.".freeze

  attr_reader :schema, :feature, :source, :sentry_context, :last_error

  def initialize(schema:, feature:, source:, sentry_context: {})
    @schema = schema
    @feature = feature
    @source = source
    @sentry_context = sentry_context
  end

  def call(system_prompt:, message:)
    response = request(system_prompt: system_prompt, message: message)
    return response if response.is_a?(Hash) && response.present?
    return if request_failed?

    Rails.logger.warn("[#{source}] first attempt failed, retrying with corrective instruction")

    request(system_prompt: "#{system_prompt}\n\n#{RETRY_INSTRUCTION}", message: message)
  end

  def request_failed?
    last_error.present?
  end

  private

    def request(system_prompt:, message:)
      response =
        ::Ai::RubyLlmFactory
          .chat_with_json_output(schema, feature: feature)
          .with_instructions(system_prompt)
          .ask(message)

      ::Ai::StructuredOutput.content_of(response)
    rescue StandardError => e
      @last_error = e
      Rails.logger.error("[#{source}] AI call error: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, extra: sentry_context) if defined?(Sentry)

      nil
    end
end
