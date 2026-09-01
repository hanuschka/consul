class PollQuestionImports::GenerateService < ApplicationService
  RETRY_INSTRUCTION = "Your previous response was not valid JSON matching the schema. " \
                      "Please respond again with ONLY a JSON object matching the schema.".freeze

  AI_FEATURE = "poll_question_imports.generate".freeze

  MAX_INPUT_CHARS = 200_000

  attr_reader :question_import

  def initialize(question_import:)
    @question_import = question_import
  end

  def call
    if question_import.extracted_text.blank?
      return ServiceResult.failure(
        error: I18n.t("adm.projekts.poll_question_imports.errors.no_text")
      )
    end

    system_prompt = ::PollQuestionImports::PromptBuilder.new(
      projekt_phase: question_import.projekt_phase,
      response_language: question_import.response_language
    ).call

    data = call_ai_with_retry(system_prompt: system_prompt)
    payload = data.is_a?(Hash) ? data["poll_questions"] : nil
    questions = ::ProjektImports::Builders::PollBuilder.importable_questions(payload)

    if questions.empty?
      return ServiceResult.failure(
        error: I18n.t("adm.projekts.poll_question_imports.errors.ai_malformed")
      )
    end

    ServiceResult.success(poll_questions: questions)
  rescue StandardError => e
    Rails.logger.error("[PollQuestionImports::GenerateService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { poll_question_import_id: question_import.id }) if defined?(Sentry)

    ServiceResult.failure(
      error: I18n.t("adm.projekts.poll_question_imports.errors.generation_failed", message: e.message)
    )
  end

  private

    # The document is the user message rather than part of the instructions, so a
    # long file cannot push the transcription rules out of the model's attention.
    def analyzed_text
      @analyzed_text ||= begin
        full = question_import.extracted_text.to_s

        full.length <= MAX_INPUT_CHARS ? full : clip_to_boundary(full)
      end
    end

    def clip_to_boundary(full)
      clipped = full[0, MAX_INPUT_CHARS]
      boundary = clipped.rindex("\n\n") || clipped.rindex("\n") || clipped.rindex(" ")

      return clipped if boundary.nil? || boundary <= MAX_INPUT_CHARS / 2

      clipped[0, boundary]
    end

    def call_ai_with_retry(system_prompt:)
      response = call_ai(system_prompt: system_prompt)
      return response if response.is_a?(Hash) && response.present?

      Rails.logger.warn("[PollQuestionImports::GenerateService] first attempt failed, retrying")

      call_ai(system_prompt: "#{system_prompt}\n\n#{RETRY_INSTRUCTION}")
    end

    def call_ai(system_prompt:)
      response =
        ::Ai::RubyLlmFactory
          .chat_with_json_output(output_schema, feature: AI_FEATURE)
          .with_instructions(system_prompt)
          .ask("Document text:\n#{analyzed_text}")

      response.content
    rescue StandardError => e
      Rails.logger.error("[PollQuestionImports::GenerateService] AI call error: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, extra: { poll_question_import_id: question_import.id }) if defined?(Sentry)

      nil
    end

    def output_schema
      @output_schema ||= {
        type: "object",
        properties: {
          poll_questions: {
            type: "array",
            items: ::ProjektImports::OutputSchemaBuilder.poll_question_schema
          }
        },
        required: %w[poll_questions],
        additionalProperties: false
      }
    end
end
