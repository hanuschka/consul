class ProjektImports::ProcessWithAiService < ApplicationService
  MAX_INPUT_CHARS = 200_000

  attr_reader :text, :additional_user_instructions, :source_images, :source_label

  def initialize(
    text:, additional_user_instructions: nil, response_language: nil,
    source_images: [], source_label: nil
  )
    @text = text
    @additional_user_instructions = additional_user_instructions
    @response_language = response_language
    @source_images = Array(source_images)
    @source_label = source_label
  end

  def call
    base_prompt = load_base_prompt

    refs = ProjektImports::ReferencesBuilder.build

    system_prompt = ProjektImports::PromptBuilder.new(
      base_prompt: base_prompt,
      refs: refs,
      response_language: @response_language,
      source_images: source_images,
      additional_user_instructions: additional_user_instructions
    ).call

    schema = ProjektImports::OutputSchemaBuilder.build(refs)
    message = build_user_message

    @ai_request = ::Ai::CorrectiveJsonRequest.new(
      schema: schema,
      feature: "projekt_imports.process",
      source: self.class.name,
      sentry_context: { stage: "ai_processing", input_text_length: text.to_s.length }
    )
    data = @ai_request.call(system_prompt: system_prompt, message: message)

    if data.blank? || data["content_blocks"].blank?
      return ServiceResult.failure(
        error: ai_failure_message,
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
    ServiceResult.failure(
      error: ProjektImports::FailureReporter.error_message(
        e,
        source: self.class.name,
        stage: "ai_processing",
        key: "ai_processing_failed",
        sentry_context: { input_text_length: text.to_s.length }
      ),
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

  # The document is the whole user turn: the admin's notes moved into the
  # system prompt, so nothing the page contains can pose as them.
  def build_user_message
    ProjektImports::UntrustedContentPolicy.wrap_document(
      analyzed_text,
      tag: ProjektImports::UntrustedContentPolicy::SOURCE_DOCUMENT_TAG,
      source: source_label
    )
  end

  def analyzed_text
    @analyzed_text ||= begin
      full_text = text.to_s
      clipped_text = TextClipper.call(full_text, MAX_INPUT_CHARS)
      @original_text_length = full_text.length
      @analyzed_text_length = clipped_text.length
      @text_truncated = clipped_text.length < full_text.length
      clipped_text
    end
  end

  def ai_failure_message
    if @ai_request.request_failed?
      I18n.t("adm.projekts.imports.errors.ai_request_failed")
    else
      I18n.t("adm.projekts.imports.errors.ai_malformed")
    end
  end

  def malformed_details(data)
    reason = data.blank? ? "ai_call_failed" : "schema_non_adherence"

    {
      "failure_reason" => reason,
      "input_text_length" => @original_text_length || text.to_s.length,
      "analyzed_text_length" => @analyzed_text_length,
      "input_truncated" => @text_truncated,
      "ai_error_class" => @ai_request.last_error&.class&.name,
      "ai_error_message" => @ai_request.last_error&.message,
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
