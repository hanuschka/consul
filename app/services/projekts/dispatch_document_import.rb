class Projekts::DispatchDocumentImport < ApplicationService
  attr_reader :projekt, :file

  def initialize(projekt:, file:)
    @projekt = projekt
    @file = file
  end

  def call
    extraction_result = ProjektContentBlocks::DocumentTextExtractor.call(file: file)

    unless extraction_result.success?
      projekt.update_columns(
        build_file_import_status: "failed",
        build_file_import_data: { error: { message: extraction_result.error } }
      )
      return ServiceResult.failure(error: extraction_result.error)
    end

    projekt.update_columns(
      build_file_import_status: "pending",
      build_file_import_data: { text: extraction_result.text }
    )

    Projekts::ImportContentFromDocumentJob.perform_later(projekt.id)

    ServiceResult.success
  end
end
