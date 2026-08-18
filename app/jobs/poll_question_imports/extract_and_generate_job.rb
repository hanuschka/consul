class PollQuestionImports::ExtractAndGenerateJob < ApplicationJob
  queue_as :projekt_imports

  def perform(poll_question_import_id)
    question_import = ::PollQuestionImport.find(poll_question_import_id)

    if question_import.extracted_text.blank?
      question_import.update!(status: "extracting")

      extract_result = extract_all_files(question_import)

      if !extract_result.success?
        question_import.mark_failed!(extract_result.error)
        return
      end

      question_import.update!(
        extracted_text: extract_result.data[:text],
        content_locale: ::PollQuestionImport.default_content_locale
      )
    end

    question_import.update!(status: "processing")

    result = ::PollQuestionImports::GenerateService.call(question_import: question_import)

    if result.success?
      question_import.update!(status: "completed", result: result.data[:poll_questions], error_message: nil)
    else
      question_import.mark_failed!(result.error)
    end
  rescue StandardError => e
    Rails.logger.error("[PollQuestionImports::ExtractAndGenerateJob] failed: #{e.message}")

    if defined?(Sentry)
      Sentry.capture_exception(e, extra: { poll_question_import_id: poll_question_import_id })
    end

    ::PollQuestionImport.find_by(id: poll_question_import_id)&.mark_failed!(e.message)

    raise
  end

  private

    # The documents are read one after another and joined with the same separator
    # the projekt import uses, so the model sees where one file ends and the next
    # begins without being told twice.
    def extract_all_files(question_import)
      chunks = []

      question_import.source_files.each do |source_file|
        result = extract_single_file(source_file)

        if !result.success?
          return ServiceResult.failure(
            error: I18n.t("adm.projekts.poll_question_imports.errors.extract_file_failed",
                          filename: source_file.filename.to_s, message: result.error)
          )
        end

        chunks << result.data[:text]
      end

      ServiceResult.success(text: chunks.join("\n\n---\n\n"))
    end

    def extract_single_file(source_file)
      ::AttachmentUpload.open(source_file) do |file|
        ::DocumentTextExtractor.call(file: file)
      end
    end
end
