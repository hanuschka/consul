class ProjektContentBlocks::DocumentTextExtractor < ApplicationService
  attr_reader :file, :file_path, :extension

  def initialize(file:)
    @file = file
    @file_path = file.path
    @extension = File.extname(file.original_filename).downcase.delete('.')
  end

  def call
    Rails.logger.info("[DocumentTextExtractor] Starting text extraction for file: #{file.original_filename}, extension: #{extension}")

    case extension
    when 'pdf'
      extract_from_pdf
    when 'docx'
      extract_from_docx
    when 'odt'
      extract_from_odt
    else
      Rails.logger.error("[DocumentTextExtractor] Unsupported file format: #{extension} for file: #{file.original_filename}")
      ServiceResult.failure(error: "Nicht unterstütztes Dateiformat: #{extension}")
    end
  end

  private

  def extract_from_pdf
    Rails.logger.info("[DocumentTextExtractor] Extracting text from PDF: #{file.original_filename}")

    require 'pdf-reader'
    reader = PDF::Reader.new(file_path)
    text = reader.pages.map(&:text).join("\n\n")

    if text.strip.empty?
      Rails.logger.error("[DocumentTextExtractor] PDF contains no extractable text: #{file.original_filename}")
      return ServiceResult.failure(error: "PDF enthält keinen extrahierbaren Text")
    end

    Rails.logger.info("[DocumentTextExtractor] Successfully extracted #{text.length} characters from PDF: #{file.original_filename}")
    ServiceResult.success(text: text)
  rescue => e
    Rails.logger.error("[DocumentTextExtractor] Error extracting text from PDF #{file.original_filename}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    ServiceResult.failure(error: "Fehler beim Verarbeiten der PDF-Datei: #{e.message}")
  end

  def extract_from_docx
    Rails.logger.info("[DocumentTextExtractor] Extracting text from DOCX: #{file.original_filename}")

    require 'docx'
    doc = Docx::Document.open(file_path)
    text = doc.paragraphs.map(&:text).join("\n\n")

    if text.strip.empty?
      Rails.logger.error("[DocumentTextExtractor] DOCX contains no text: #{file.original_filename}")
      return ServiceResult.failure(error: "DOCX enthält keinen Text")
    end

    Rails.logger.info("[DocumentTextExtractor] Successfully extracted #{text.length} characters from DOCX: #{file.original_filename}")
    ServiceResult.success(text: text)
  rescue => e
    Rails.logger.error("[DocumentTextExtractor] Error extracting text from DOCX #{file.original_filename}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    ServiceResult.failure(error: "Fehler beim Verarbeiten der DOCX-Datei: #{e.message}")
  end

  def extract_from_odt
    Rails.logger.info("[DocumentTextExtractor] Extracting text from ODT: #{file.original_filename}")

    output = `pandoc -f odt -t plain "#{file_path}" 2>&1`

    if $?.exitstatus != 0
      Rails.logger.error("[DocumentTextExtractor] Pandoc failed for ODT #{file.original_filename}: exit status #{$?.exitstatus}, output: #{output}")
      return ServiceResult.failure(error: "Fehler beim Verarbeiten der ODT-Datei")
    end

    if output.strip.empty?
      Rails.logger.error("[DocumentTextExtractor] ODT contains no text: #{file.original_filename}")
      return ServiceResult.failure(error: "ODT enthält keinen Text")
    end

    Rails.logger.info("[DocumentTextExtractor] Successfully extracted #{output.length} characters from ODT: #{file.original_filename}")
    ServiceResult.success(text: output)
  rescue => e
    Rails.logger.error("[DocumentTextExtractor] Error extracting text from ODT #{file.original_filename}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    ServiceResult.failure(error: "Fehler beim Verarbeiten der ODT-Datei: #{e.message}")
  end
end
