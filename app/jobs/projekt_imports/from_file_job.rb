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

    warn_about_unreadable_pdf_images(projekt_import)

    ai_result = ProjektImports::ProcessWithAiService.call(
      text: extract_result.data[:text],
      additional_user_instructions: projekt_import.additional_user_instructions,
      response_language: projekt_import.import_response_language
    )

    if !ai_result.success?
      projekt_import.mark_failed!(ai_result.error, stage: "ai_processing", details: ai_result.error_details)
      return
    end

    projekt_import.update!(ai_result: ai_result.data[:ai_result])

    text_truncated = ai_result.data[:text_truncated]

    if text_truncated
      projekt_import.add_warning!(
        "input_truncated: analyzed #{ai_result.data[:analyzed_text_length]} of #{ai_result.data[:original_text_length]} chars"
      )
    end

    transition_to_chat(projekt_import, text_truncated: text_truncated)
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

    ServiceResult.success(text: chunks.join("\n\n---\n\n"))
  end

  def extract_single_file(source_file)
    ::AttachmentUpload.open(source_file) do |file|
      DocumentTextExtractor.call(file: file)
    end
  end

  # Raised at extraction time rather than only when the projekt is created: the
  # admin is still in the chat here, so there is time to upload the images by
  # hand before anything is built.
  def warn_about_unreadable_pdf_images(projekt_import)
    return if ::DocumentImageExtractor.pdfimages_available?

    projekt_import.source_files.each do |source_file|
      filename = source_file.blob.filename.to_s
      next if File.extname(filename).downcase != ".pdf"
      next if !pdf_carries_images?(source_file)

      projekt_import.add_warning!(
        I18n.t("adm.projekts.imports.warnings.pdf_images_tool_missing", filename: filename)
      )
    end
  end

  def pdf_carries_images?(source_file)
    ::AttachmentUpload.open(source_file) do |file|
      ::DocumentImageExtractor.call(file: file).data[:unextractable]
    end
  end

  def transition_to_chat(projekt_import, text_truncated: false)
    ai_chat = AiChat.create!(resource: projekt_import)

    initial_message_result = ProjektImports::BuildInitialMessageService.call(
      projekt_import: projekt_import,
      text_truncated: text_truncated
    )

    if initial_message_result.success?
      ai_chat.ai_chat_messages.create!(
        role: "assistant",
        content: initial_message_result.data[:content],
        status: "completed"
      )
    end

    projekt_import.update!(status: "chatting")
  end
end
