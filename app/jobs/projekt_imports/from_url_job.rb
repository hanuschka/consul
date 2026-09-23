class ProjektImports::FromUrlJob < ApplicationJob
  queue_as :projekt_imports

  def perform(projekt_import_id)
    projekt_import = ProjektImport.find(projekt_import_id)
    projekt_import.update!(status: "extracting")

    fetch_result = ProjektImports::FetchUrlService.call(source_url: projekt_import.source_url)

    if !fetch_result.success?
      projekt_import.mark_failed!(fetch_result.error, stage: "fetch_url", details: fetch_result.error_details)
      return
    end

    text_result = ProjektImports::ExtractHtmlTextService.call(
      html: fetch_result.data[:html],
      source_url: fetch_result.data[:final_url]
    )

    if !text_result.success?
      projekt_import.mark_failed!(text_result.error, stage: "extract_html", details: text_result.error_details)
      return
    end

    projekt_import.update!(
      status: "processing",
      extracted_text: text_result.data[:text],
      content_locale: ProjektImport.default_content_locale
    )

    if text_result.data[:hidden_content_removed]
      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.hidden_content_removed"),
        stage: ProjektImport::ANALYSIS_WARNING_STAGE
      )
    end

    # A page carries no pictures the import can lift the way a document does —
    # the images on it belong to whoever published it — so the title image is
    # left unset and the admin picks "create one with AI" in the chat if they
    # want one.
    ai_result = ProjektImports::ProcessWithAiService.call(
      text: text_result.data[:text],
      additional_user_instructions: projekt_import.additional_user_instructions,
      response_language: projekt_import.import_response_language,
      source_images: [],
      source_label: fetch_result.data[:final_url]
    )

    if !ai_result.success?
      projekt_import.mark_failed!(ai_result.error, stage: "ai_processing", details: ai_result.error_details)
      return
    end

    projekt_import.update!(ai_result: ai_result.data[:ai_result])

    text_truncated = ai_result.data[:text_truncated]

    if text_truncated
      projekt_import.add_warning!(
        "input_truncated: analyzed #{ai_result.data[:analyzed_text_length]} of #{ai_result.data[:original_text_length]} chars",
        stage: ProjektImport::ANALYSIS_WARNING_STAGE
      )
    end

    ProjektImports::StartChatService.call(projekt_import: projekt_import, text_truncated: text_truncated)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::FromUrlJob] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import_id, stage: "from_url_job" }) if defined?(Sentry)
    pi = ProjektImport.find_by(id: projekt_import_id)
    pi&.mark_failed!(e.message, exception: e)
    raise
  end
end
