class DocumentTextExtractor < ApplicationService
  attr_reader :file, :file_path, :extension

  def initialize(file:)
    @file = file
    @file_path = file.path
    @extension = File.extname(file.original_filename).downcase.delete('.')
  end

  def call
    case extension
    when 'pdf'
      extract_from_pdf
    when 'docx'
      extract_from_docx
    when 'odt'
      extract_from_odt
    else
      ServiceResult.failure(error: "Nicht unterstütztes Dateiformat: #{extension}")
    end
  end

  private

  def extract_from_pdf
    require 'pdf-reader'
    reader = PDF::Reader.new(file_path)
    text = reader.pages.map(&:text).join("\n\n")

    return ServiceResult.failure(error: "PDF enthält keinen extrahierbaren Text") if text.strip.empty?

    ServiceResult.success(text: text)
  end

  def extract_from_docx
    require 'docx'
    doc = Docx::Document.open(file_path)
    text = doc.paragraphs.map(&:text).join("\n\n")

    return ServiceResult.failure(error: "DOCX enthält keinen Text") if text.strip.empty?

    ServiceResult.success(text: text)
  end

  def extract_from_odt
    output = `pandoc -f odt -t plain "#{file_path}" 2>&1`

    return ServiceResult.failure(error: "Fehler beim Verarbeiten der ODT-Datei") if $?.exitstatus != 0
    return ServiceResult.failure(error: "ODT enthält keinen Text") if output.strip.empty?

    ServiceResult.success(text: output)
  end
end
