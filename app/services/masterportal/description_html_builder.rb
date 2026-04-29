class Masterportal::DescriptionHtmlBuilder < ApplicationService
  CONTAINER_STYLE = [
    "margin: 1.5rem 0",
    "border: 1px solid #e2e8f0",
    "border-radius: 12px",
    "background: #ffffff",
    "overflow: hidden"
  ].join("; ").freeze

  HEADER_STYLE = [
    "padding: 1rem 1.5rem",
    "background: #f8fafc",
    "border-bottom: 1px solid #e2e8f0"
  ].join("; ").freeze

  EYEBROW_STYLE = [
    "display: block",
    "margin-bottom: 0.25rem",
    "font-size: 0.75rem",
    "font-weight: 700",
    "letter-spacing: 0.08em",
    "text-transform: uppercase",
    "color: #2563eb"
  ].join("; ").freeze

  TITLE_STYLE = [
    "margin: 0",
    "font-size: 1.0625rem",
    "font-weight: 600",
    "color: #0f172a",
    "line-height: 1.3"
  ].join("; ").freeze

  TABLE_STYLE = [
    "width: 100%",
    "border-collapse: collapse",
    "table-layout: fixed"
  ].join("; ").freeze

  ROW_BASE = "border-top: 1px solid #f1f5f9".freeze
  ROW_ZEBRA = "background: #fafbfc".freeze

  TH_STYLE = [
    "width: 38%",
    "padding: 0.75rem 1.5rem",
    "text-align: left",
    "vertical-align: top",
    "font-size: 0.75rem",
    "font-weight: 700",
    "letter-spacing: 0.06em",
    "text-transform: uppercase",
    "color: #64748b",
    "word-break: break-word"
  ].join("; ").freeze

  TD_STYLE = [
    "padding: 0.75rem 1.5rem",
    "vertical-align: top",
    "font-size: 0.9375rem",
    "color: #0f172a",
    "word-break: break-word"
  ].join("; ").freeze

  def initialize(pin:, fallback: nil)
    @pin = pin
    @fallback = fallback.to_s
  end

  def call
    parts = []
    parts << intro_paragraph if intro_text.present?
    parts << properties_section if rows.any?

    return wrap(@fallback) if parts.empty?

    parts.join("\n")
  end

  private

    def intro_text
      @intro_text ||= @pin.description.to_s.strip.presence || @fallback.presence
    end

    def intro_paragraph
      "<p>#{escape(intro_text)}</p>"
    end

    def rows
      @rows ||= @pin.properties.to_h.reject { |_key, value| value.to_s.strip.empty? }
    end

    def properties_section
      <<~HTML
        <div style="#{CONTAINER_STYLE}">
          <div style="#{HEADER_STYLE}">
            <span style="#{EYEBROW_STYLE}">Masterportal</span>
            <h3 style="#{TITLE_STYLE}">#{escape(properties_heading)}</h3>
          </div>
          <table style="#{TABLE_STYLE}"><tbody>#{rows_html}</tbody></table>
        </div>
      HTML
    end

    def rows_html
      rows.each_with_index.map { |(key, value), index| row_html(key, value, index) }.join
    end

    def row_html(key, value, index)
      row_style = [ROW_BASE, (ROW_ZEBRA if index.odd?)].compact.join("; ")

      "<tr style=\"#{row_style}\">" \
        "<th style=\"#{TH_STYLE}\">#{escape(key.to_s)}</th>" \
        "<td style=\"#{TD_STYLE}\">#{escape(value.to_s)}</td>" \
      "</tr>"
    end

    def properties_heading
      I18n.t(
        "masterportal.description.properties_heading",
        default: "Eigenschaften aus dem Masterportal"
      )
    end

    def wrap(text)
      "<p>#{escape(text)}</p>"
    end

    def escape(text)
      ERB::Util.html_escape(text)
    end
end
