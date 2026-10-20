module MunicipalPlans
  class LegacyImport
    module Html
      BREAK = %r{<br\s*/?>}i
      BLOCKS = %w[p div h1 h2 h3 h4 h5 h6 table tr blockquote section article pre].freeze

      module_function

      def to_plain_text(html)
        text = render(Nokogiri::HTML::DocumentFragment.parse(html.to_s).children)

        text.tr(" ", " ").split("\n").map { |line| line.squeeze(" ").strip }.join("\n")
            .gsub(/\n{3,}/, "\n\n").strip.presence
      end

      def single_line(html)
        to_plain_text(html)&.squish.presence
      end

      def render(nodes)
        nodes.map { |node| render_node(node) }.join
      end

      def render_node(node)
        return node.text.gsub(/\s+/, " ") if node.text?
        return "" unless node.element?

        case node.name
        when "br" then "\n"
        when "a" then render_link(node)
        when "ul", "ol" then render_list(node)
        when "li" then "\n– #{render(node.children).strip}\n"
        when *BLOCKS then "\n\n#{render(node.children)}\n\n"
        else render(node.children)
        end
      end

      def render_link(node)
        text = render(node.children).strip
        url = node["href"].to_s.strip
        return text if url.blank?
        return url if text.blank? || text == url

        "#{text} (#{url})"
      end

      def render_list(node)
        items = node.element_children.select { |child| child.name == "li" }
        lines = items.each_with_index.map do |item, index|
          marker = node.name == "ol" ? "#{index + 1}." : "–"
          "#{marker} #{render(item.children).strip}"
        end

        "\n\n#{lines.join("\n")}\n\n"
      end
    end
  end
end
