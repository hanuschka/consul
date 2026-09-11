class ProjektImports::FromFileJob < ApplicationJob
  queue_as :projekt_imports

  def perform(projekt_import_id)
    projekt_import = ProjektImport.find(projekt_import_id)
    projekt_import.update!(status: "extracting")

    extract_result = extract_all_files(projekt_import)

    if !extract_result.success?
      projekt_import.mark_failed!(extract_result.error, stage: "extract")
      return
    end

    projekt_import.update!(
      status: "processing",
      extracted_text: extract_result.data[:text],
      content_locale: ProjektImport.default_content_locale
    )

    # Before the analysis call on purpose: the model can only reserve a content
    # block with an image slot for images it knows about, and an image that
    # cannot be carried over is worth reporting while the admin is still in the
    # chat and can upload it by hand.
    images_result = ProjektImports::ExtractSourceImagesService.call(projekt_import: projekt_import)

    if extract_result.data[:hidden_content_removed]
      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.hidden_content_removed"),
        stage: ProjektImport::ANALYSIS_WARNING_STAGE
      )
    end

    ai_result = ProjektImports::ProcessWithAiService.call(
      text: extract_result.data[:text],
      additional_user_instructions: projekt_import.additional_user_instructions,
      response_language: projekt_import.import_response_language,
      source_images: images_result.data[:source_images],
      source_label: projekt_import.source_files.map { |file| file.filename.to_s }.join(", ")
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
    Rails.logger.error("[ProjektImports::FromFileJob] failed: #{e.message}")
    Sentry.capture_exception(e, extra: { projekt_import_id: projekt_import_id, stage: "from_file_job" }) if defined?(Sentry)
    pi = ProjektImport.find_by(id: projekt_import_id)
    pi&.mark_failed!(e.message, exception: e)
    raise
  end

  private

  def extract_all_files(projekt_import)
    chunks = []

    projekt_import.source_files.each do |source_file|
      result = extract_single_file(source_file)

      if !result.success?
        return ServiceResult.failure(
          error: I18n.t("adm.projekts.imports.errors.extract_file_failed",
            filename: source_file.filename.to_s, message: result.error)
        )
      end

      chunks << result.data[:text]
    end

    visible = InvisibleUnicodeStripper.call(chunks.join("\n\n---\n\n"))

    ServiceResult.success(
      text: visible[:text],
      hidden_content_removed: visible[:removed_characters].positive?
    )
  end

  def extract_single_file(source_file)
    ::AttachmentUpload.open(source_file) do |file|
      DocumentTextExtractor.call(file: file)
    end
  end
end
