class ProjektContentBlocks::AiGenerateWithFile < ApplicationService
  CONTENT_BLOCK_LOCALE = "de".freeze

  attr_reader :projekt

  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    projekt.update_column(:import_file_status, "processing")

    import_file_data = projekt.import_file_data || {}

    ai_result = ProjektImports::ProcessWithAiService.call(
      text: import_file_data["text"],
      additional_user_instructions: import_file_data["user_prompt"],
      response_language: response_language
    )

    if !ai_result.success?
      return mark_failed(ai_result.error)
    end

    resolve_result = ProjektImports::ResolveContentBlockHtmlService.call(
      blocks: ai_result.data[:ai_result]["content_blocks"],
      sentry_context: { projekt_id: projekt.id }
    )

    if !resolve_result.success?
      return mark_failed(resolve_result.error)
    end

    content_blocks = ProjektContentBlocks::Services::CreateFromImportData.call(
      projekt: projekt,
      blocks: resolve_result.data[:blocks],
      locale: CONTENT_BLOCK_LOCALE
    )

    projekt.update_columns(
      import_file_status: "completed",
      import_file_data: { content_blocks: content_blocks }
    )

    ServiceResult.success(content_blocks: content_blocks)
  end

  private

  def response_language
    Rails.env.development? ? "English" : "German"
  end

  def mark_failed(message)
    projekt.update_columns(
      import_file_status: "failed",
      import_file_data: { error: { message: message } }
    )

    ServiceResult.failure(error: message)
  end
end
