# Pulls the readable text out of an uploaded document.
#
# DOCX and ODT are converted by pandoc rather than parsed in Ruby. The docx gem
# reads body paragraphs only (w:body/w:p), so tables, text boxes, headers and
# footers never reach the model; its separate table reader carries no
# gridSpan/vMerge handling and no record of where a table sat among the
# paragraphs, which is exactly what a sentence like "the table below shows"
# depends on.
#
# HTML is the conversion target because it is the only format pandoc writes
# that can express merged cells — every Markdown table writer flattens them.
#
# PDF holds no structure to convert, only glyphs at coordinates. poppler's
# pdftotext keeps the horizontal whitespace that separates columns, which is as
# close to a table as the format allows; pdf-reader stands in where poppler is
# missing so a server without it degrades instead of failing the import.
class DocumentTextExtractor < ApplicationService
  PANDOC_FORMATS = %w[docx odt].freeze
  PLAIN_TEXT_FORMATS = %w[txt md markdown].freeze

  # A converted document is markup rather than prose, and the HTML writer
  # inflates the byte count well past the source. Generous because the import
  # truncates for the model further down anyway, and a silently clipped
  # document is worse than a slow one.
  MAX_OUTPUT = 8.megabytes

  # Long enough for a document of a few hundred pages, short enough that a
  # crafted file cannot hold a worker for as long as the queue allows.
  CONVERSION_TIMEOUT = 90.seconds

  attr_reader :file, :file_path, :extension

  def initialize(file:)
    @file = file
    @file_path = file.path
    @extension = File.extname(file.original_filename).downcase.delete(".")
  end

  def call
    case extension
    when "pdf"
      extract_from_pdf
    when *PANDOC_FORMATS
      extract_via_pandoc
    when *PLAIN_TEXT_FORMATS
      extract_from_plain_text
    else
      ServiceResult.failure(error: "Nicht unterstütztes Dateiformat: #{extension}")
    end
  end

  private

  def extract_from_plain_text
    text = File.read(file_path, encoding: "UTF-8", invalid: :replace, undef: :replace)

    return ServiceResult.failure(error: "Datei enthält keinen Text") if text.strip.empty?

    ServiceResult.success(text: text)
  end

  def extract_via_pandoc
    result = GuardedCommand.run(
      "pandoc", "-f", extension, "-t", "html", "--wrap=none", file_path,
      timeout: CONVERSION_TIMEOUT, output_limit: MAX_OUTPUT
    )

    if !result.success?
      warn_about_command("pandoc -f #{extension}", result)

      return ServiceResult.failure(error: "Fehler beim Verarbeiten der #{extension.upcase}-Datei")
    end

    text = result.stdout

    return ServiceResult.failure(error: "#{extension.upcase} enthält keinen Text") if text.strip.empty?

    ServiceResult.success(text: text)
  end

  def extract_from_pdf
    text = pdftotext_layout || pdf_reader_text

    return ServiceResult.failure(error: "PDF enthält keinen extrahierbaren Text") if text.blank?
    return ServiceResult.failure(error: "PDF enthält keinen extrahierbaren Text") if text.strip.empty?

    ServiceResult.success(text: text)
  end

  # -layout reproduces the page's column positions with spaces, keeping the
  # rows of a table on one line each. Returns nil — not an empty string — when
  # poppler cannot be used at all, so a genuinely textless PDF is still told
  # apart from a missing binary.
  def pdftotext_layout
    return nil if !ExternalTool.installed?("pdftotext")

    result = GuardedCommand.run(
      "pdftotext", "-layout", "-enc", "UTF-8", file_path, "-",
      timeout: CONVERSION_TIMEOUT, output_limit: MAX_OUTPUT
    )

    if !result.success?
      warn_about_command("pdftotext -layout", result)

      return nil
    end

    result.stdout
  end

  def pdf_reader_text
    PDF::Reader.new(file_path).pages.map(&:text).join("\n\n")
  rescue StandardError => e
    Rails.logger.warn("[DocumentTextExtractor] pdf-reader fallback failed: #{e.message}")

    nil
  end

  def warn_about_command(label, result)
    Rails.logger.warn(
      "[DocumentTextExtractor] #{label} #{result.failure_reason}: #{result.stderr.to_s.strip.truncate(300)}"
    )
  end
end
