class Masterportal::DescriptionHtmlBuilder < ApplicationService
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
      @rows ||= @pin.properties.to_h
    end

    def properties_section
      body = rows.map { |key, value| row_html(key, value) }.join

      "<h3>#{escape(properties_heading)}</h3>" \
      "<table><tbody>#{body}</tbody></table>"
    end

    def properties_heading
      I18n.t(
        "masterportal.description.properties_heading",
        default: "Eigenschaften aus dem Masterportal"
      )
    end

    def row_html(key, value)
      "<tr><th>#{escape(key.to_s)}</th><td>#{escape(value.to_s)}</td></tr>"
    end

    def wrap(text)
      "<p>#{escape(text)}</p>"
    end

    def escape(text)
      ERB::Util.html_escape(text)
    end
end
