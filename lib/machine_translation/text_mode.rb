module MachineTranslation
  module TextMode
    MARKUP = %r{<[a-zA-Z/!]}
    FALLBACK = { plain: :xml }.freeze

    class << self
      def mode_for(text, html: false)
        html || text.match?(MARKUP) ? :html : :plain
      end

      def fallback_for(mode)
        FALLBACK[mode]
      end

      def options(mode)
        case mode
        when :html then { tag_handling: "html", ignore_tags: "x" }
        when :xml then { tag_handling: "xml", ignore_tags: "x" }
        else {}
        end
      end

      def prepare(text, mode)
        case mode
        when :html then wrap(text)
        when :xml then wrap(CGI.escapeHTML(text))
        else text
        end
      end

      def restore(text, mode)
        case mode
        when :html then unwrap(text)
        when :xml then CGI.unescapeHTML(unwrap(text))
        else text
        end
      end

      def wrap(text)
        text.gsub(INTERPOLATION) { |match| "<x>#{match}</x>" }
      end

      def unwrap(text)
        text.gsub(%r{</?x>}, "")
      end
    end
  end
end
