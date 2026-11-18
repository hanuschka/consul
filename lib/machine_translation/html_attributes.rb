module MachineTranslation
  module HtmlAttributes
    ATTRIBUTES = %w[alt title].freeze
    SELECTOR = ATTRIBUTES.map { |attribute| "[#{attribute}]" }.join(", ").freeze
    ATTRIBUTE_PATTERN = /\b(?:#{ATTRIBUTES.join("|")})\s*=/i

    module_function

    def extract(html)
      return [] unless candidate?(html)

      fragment(html).css(SELECTOR).flat_map { |node| ATTRIBUTES.filter_map { |attribute| node[attribute] } }
                    .uniq
                    .select { |value| MachineTranslation.translatable_value?(value) }
    end

    def apply(html, translations)
      return html if translations.blank? || !candidate?(html)

      document = fragment(html)
      changed = false

      document.css(SELECTOR).each do |node|
        ATTRIBUTES.each do |attribute|
          translated = translations[node[attribute]]
          next if translated.blank? || translated == node[attribute]

          node[attribute] = translated
          changed = true
        end
      end

      changed ? document.to_html : html
    end

    def translate(values, target_locale:, source_locale:)
      return {} if values.empty?

      translated = Deepl::Client.new.translate(values.map { |value| CGI.escapeHTML(value) },
                                               target_locale: target_locale,
                                               source_locale: source_locale,
                                               tag_handling: "html")

      values.zip(translated.map { |value| CGI.unescapeHTML(value.to_s) }).to_h
    end

    def candidate?(html)
      html.is_a?(String) && html.match?(ATTRIBUTE_PATTERN)
    end

    def fragment(html)
      Nokogiri::HTML5.fragment(html)
    end
  end
end
