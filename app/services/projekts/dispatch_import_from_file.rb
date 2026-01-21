class Projekts::DispatchImportFromFile < ApplicationService
  attr_reader :projekt, :file, :user_prompt

  def initialize(projekt:, file:, user_prompt: nil)
    @projekt = projekt
    @file = file
    @user_prompt = user_prompt
  end

  def call
    extraction_result = ProjektContentBlocks::DocumentTextExtractor.call(file: file)

    unless extraction_result.success?
      projekt.update_columns(
        import_file_status: "failed",
        import_file_data: { error: { message: extraction_result.error } }
      )
      return ServiceResult.failure(error: extraction_result.error)
    end

    import_data = { text: extraction_result.text }
    import_data[:user_prompt] = user_prompt if user_prompt.present?

    projekt.update_columns(
      import_file_status: "pending",
      import_file_data: import_data
    )

    Projekts::ImportContentFromDocumentJob.perform_later(projekt.id)

    ServiceResult.success
  end
end
