# Turns a fetched page into the same plain text a document extraction produces,
# so ProcessWithAiService cannot tell the two sources apart.
#
# Kept out of DocumentTextExtractor on purpose: that service dispatches on a
# filename extension and a page has none.
class ProjektImports::ExtractHtmlTextService < ApplicationService
  # Chrome, not content. Removing them before the walk is what keeps a cookie
  # banner and a site-wide menu out of the projekt description.
  DROPPED_SELECTORS = %w[
    script style noscript template iframe svg
    nav header footer aside form
    [role="navigation"] [role="banner"] [role="contentinfo"] [aria-hidden="true"]
  ].freeze

  BLOCK_SELECTORS = "h1, h2, h3, h4, h5, h6, p, li, dt, dd, td, th, blockquote, pre, figcaption".freeze

  HEADING_PREFIXES = {
    "h1" => "# ", "h2" => "## ", "h3" => "### ",
    "h4" => "#### ", "h5" => "##### ", "h6" => "###### "
  }.freeze

  MIN_USEFUL_LENGTH = 200

  def initialize(html:, source_url: nil)
    @html = html.to_s
    @source_url = source_url
  end

  def call
    return failure("empty") if html.blank?

    document = Nokogiri::HTML(html)
    document.css(DROPPED_SELECTORS.join(", ")).remove

    text = [page_title(document), *block_lines(document)].compact_blank.join("\n\n")

    return failure("unreadable") if text.length < MIN_USEFUL_LENGTH

    ServiceResult.success(text: text)
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ExtractHtmlTextService] #{e.class}: #{e.message}")
    failure("unreadable")
  end

  private

    attr_reader :html, :source_url

    def page_title(document)
      title = squish(document.at_css("title")&.text)
      return nil if title.blank?

      "# #{title}"
    end

    # Only blocks with no block descendant of their own are emitted, so a <p>
    # inside an <li> is written once rather than as both the item and the
    # paragraph.
    def block_lines(document)
      body = document.at_css("body") || document

      body.css(BLOCK_SELECTORS).filter_map do |node|
        next if node.at_css(BLOCK_SELECTORS).present?

        content = squish(node.text)
        next if content.blank?

        "#{HEADING_PREFIXES.fetch(node.name, '')}#{content}"
      end
    end

    def squish(value)
      value.to_s.gsub(/[[:space:]]+/, " ").strip
    end

    def failure(reason)
      ServiceResult.failure(
        error: I18n.t("adm.projekts.imports.errors.url.#{reason}"),
        error_details: { "reason" => reason, "source_url" => source_url }.compact
      )
    end
end
