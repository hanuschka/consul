class ProjektImports::ProcessWithAiService < ApplicationService
  RETRY_INSTRUCTION = "Your previous response was not valid JSON matching the schema. Please respond again with ONLY a JSON object matching the schema."

  MAX_INPUT_CHARS = 200_000

  attr_reader :text, :additional_user_instructions

  def initialize(text:, additional_user_instructions: nil, response_language: nil)
    @text = text
    @additional_user_instructions = additional_user_instructions
    @response_language = response_language
  end

  def call
    base_prompt = load_base_prompt

    refs = ProjektImports::ReferencesBuilder.build

    system_prompt = ProjektImports::PromptBuilder.new(
      base_prompt: base_prompt,
      refs: refs,
      response_language: @response_language
    ).call

    schema = ProjektImports::OutputSchemaBuilder.build(refs)
    message = build_user_message

    data = call_ai_with_retry(system_prompt: system_prompt, schema: schema, message: message)

    if data.blank? || data["content_blocks"].blank?
      return ServiceResult.failure(
        error: I18n.t("adm.projekts.imports.errors.ai_malformed"),
        error_details: malformed_details(data)
      )
    end

    ensure_clarification_questions(data)

    ServiceResult.success(
      ai_result: data,
      text_truncated: @text_truncated,
      original_text_length: @original_text_length,
      analyzed_text_length: @analyzed_text_length
    )
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ProcessWithAiService] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { stage: "ai_processing", input_text_length: text.to_s.length }) if defined?(Sentry)
    ServiceResult.failure(
      error: I18n.t("adm.projekts.imports.errors.ai_processing_failed", message: e.message),
      error_details: {
        "failure_reason" => "exception",
        "error_class" => e.class.name,
        "error_message" => e.message,
        "input_text_length" => text.to_s.length
      }
    )
  end

  private

  def load_base_prompt
    response = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(prompt_key)
    prompt = response.parsed_response&.dig("consul_ai_prompt", "prompt")

    if prompt.blank?
      raise I18n.t("adm.projekts.imports.errors.dt_prompt_missing")
    end

    prompt
  end

  def prompt_key
    return :admin_projekt_import_staging if Rails.env.staging?

    :admin_projekt_import
  end

  def build_user_message
    parts = ["Document text:\n#{analyzed_text}"]

    if additional_user_instructions.present?
      parts << "Additional context about this project:\n#{additional_user_instructions}"
    end

    parts.join("\n\n")
  end

  def analyzed_text
    @analyzed_text ||= begin
      full = text.to_s
      @original_text_length = full.length
      budget = MAX_INPUT_CHARS

      if full.length <= budget
        @text_truncated = false
        @analyzed_text_length = full.length
        full
      else
        @text_truncated = true
        clipped = clip_to_boundary(full, budget)
        @analyzed_text_length = clipped.length
        clipped
      end
    end
  end

  def clip_to_boundary(full, budget)
    clipped = full[0, budget]
    boundary = clipped.rindex("\n\n") || clipped.rindex("\n") || clipped.rindex(" ")

    return clipped if boundary.nil? || boundary <= budget / 2

    clipped[0, boundary]
  end

  def call_ai_with_retry(system_prompt:, schema:, message:)
    response = call_ai(system_prompt: system_prompt, schema: schema, message: message)
    return response if response.is_a?(Hash) && response.present?

    Rails.logger.warn("[ProjektImports::ProcessWithAiService] first attempt failed, retrying with corrective instruction")

    call_ai(
      system_prompt: "#{system_prompt}\n\n#{RETRY_INSTRUCTION}",
      schema: schema,
      message: message
    )
  end

  def call_ai(system_prompt:, schema:, message:)
    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(schema)
        .with_instructions(system_prompt)
        .ask(message)

    response.content
  rescue StandardError => e
    @last_ai_error = e
    Rails.logger.error("[ProjektImports::ProcessWithAiService] AI call error: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, extra: { stage: "ai_processing", input_text_length: text.to_s.length }) if defined?(Sentry)
    nil
  end

  def malformed_details(data)
    reason = data.blank? ? "ai_call_failed" : "schema_non_adherence"

    {
      "failure_reason" => reason,
      "input_text_length" => @original_text_length || text.to_s.length,
      "analyzed_text_length" => @analyzed_text_length,
      "input_truncated" => @text_truncated,
      "ai_error_class" => @last_ai_error&.class&.name,
      "ai_error_message" => @last_ai_error&.message,
      "returned_keys" => (data.is_a?(Hash) ? data.keys : nil)
    }.compact
  end

  def ensure_clarification_questions(data)
    return if data["clarification_questions"].is_a?(Array) && data["clarification_questions"].size >= 2

    data["needs_clarification"] = true
    data["clarification_questions"] = default_clarification_questions(data)
  end

  def default_clarification_questions(data)
    questions = []

    questions << I18n.t("adm.projekts.imports.default_questions.title_correct", title: data["title"])

    if data["phases"].blank?
      questions << I18n.t("adm.projekts.imports.default_questions.phases_missing")
    else
      questions << I18n.t("adm.projekts.imports.default_questions.phases_correct")
    end

    if data["projekt_start_date"].blank? && data["projekt_end_date"].blank?
      questions << I18n.t("adm.projekts.imports.default_questions.dates_missing")
    end

    questions
  end
end
