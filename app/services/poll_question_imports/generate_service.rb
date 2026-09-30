class PollQuestionImports::GenerateService < ApplicationService
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

    data = ai_request.call(system_prompt: system_prompt, message: "Document text:\n#{analyzed_text}")
    payload = data.is_a?(Hash) ? data["poll_questions"] : nil
    questions = ::ProjektImports::Builders::PollBuilder.importable_questions(payload)

    if questions.empty?
      return ServiceResult.failure(error: ai_failure_message)
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
      @analyzed_text ||= TextClipper.call(question_import.extracted_text.to_s, MAX_INPUT_CHARS)
    end

    def ai_request
      @ai_request ||= ::Ai::CorrectiveJsonRequest.new(
        schema: output_schema,
        feature: AI_FEATURE,
        source: self.class.name,
        sentry_context: { poll_question_import_id: question_import.id }
      )
    end

    def ai_failure_message
      if ai_request.request_failed?
        I18n.t("adm.projekts.poll_question_imports.errors.ai_request_failed")
      else
        I18n.t("adm.projekts.poll_question_imports.errors.ai_malformed")
      end
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
