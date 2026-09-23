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

  # Text a visitor cannot see is the place a page hides instructions for the
  # model. Only inline hiding is detectable without a rendering engine, and it
  # is what the payloads observed in the wild use; a stylesheet-driven hide is
  # out of reach here. Removed separately from the chrome above so the import
  # can tell the admin that something invisible was left out.
  HIDDEN_SELECTORS = %w[
    [hidden] details
    [style*="display:none"] [style*="display: none"]
    [style*="visibility:hidden"] [style*="visibility: hidden"]
    [style*="opacity:0"] [style*="opacity: 0"]
    [style*="font-size:0"] [style*="font-size: 0"]
    [style*="left:-9999"] [style*="left: -9999"]
    [style*="text-indent:-9999"] [style*="text-indent: -9999"]
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
    hidden_nodes_removed = remove_hidden_nodes(document)

    visible = InvisibleUnicodeStripper.call(
      [page_title(document), *block_lines(document)].compact_blank.join("\n\n")
    )
    text = visible[:text]

    return failure("unreadable") if text.length < MIN_USEFUL_LENGTH

    ServiceResult.success(
      text: text,
      hidden_content_removed: hidden_nodes_removed || visible[:removed_characters].positive?
    )
  rescue StandardError => e
    Rails.logger.error("[ProjektImports::ExtractHtmlTextService] #{e.class}: #{e.message}")
    failure("unreadable")
  end

  private

    attr_reader :html, :source_url

    # Reports whether anything with actual text went, so an empty hidden
    # spacer div does not trigger a warning the admin cannot act on.
    def remove_hidden_nodes(document)
      hidden_nodes = document.css(HIDDEN_SELECTORS.join(", "))
      carried_text = hidden_nodes.any? { |node| squish(node.text).present? }
      hidden_nodes.remove

      carried_text
    end

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
