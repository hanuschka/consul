class Deepl::Document
  DATA_URI = %r{data:[\w.+-]+/[\w.+-]+[;,][^"'()\s<>]*}
  DATA_URI_TOKEN = /data:deepl-(\d+)/

  Part = Struct.new(:text, :translated)

  def initialize(text, html:, max_bytes:)
    @data_uris = []
    source = html ? protect_data_uris(text.to_s) : text.to_s
    @segments = html && self.class.encoded_size(source) > max_bytes ? split(source, max_bytes) : [Part.new(source)]
  end

  def self.encoded_size(text)
    text.to_json.bytesize + 1
  end

  def parts
    @segments.grep(Part)
  end

  def result
    joined = @segments.map { |segment| segment.is_a?(Part) ? segment.translated : segment }.join
    joined.gsub(DATA_URI_TOKEN) { @data_uris[Regexp.last_match(1).to_i] }
  end

  private

    def protect_data_uris(text)
      text.gsub(DATA_URI) do |uri|
        @data_uris << uri
        "data:deepl-#{@data_uris.size - 1}"
      end
    end

    def split(html, max_bytes)
      @max_bytes = max_bytes
      @split_segments = []
      @current = +""
      @current_bytes = 0

      add_nodes(Nokogiri::HTML5.fragment(html).children)
      flush

      @split_segments
    end

    def add_nodes(nodes)
      nodes.each do |node|
        markup = node.to_html
        bytes = self.class.encoded_size(markup)

        if @current_bytes + bytes <= @max_bytes
          append(markup, bytes)
        elsif bytes <= @max_bytes || !node.element? || node.children.empty?
          flush
          append(markup, bytes)
        else
          flush
          open_tag, close_tag = tags_of(node)
          @split_segments << open_tag
          add_nodes(node.children)
          flush
          @split_segments << close_tag
        end
      end
    end

    def append(markup, bytes)
      @current << markup
      @current_bytes += bytes
    end

    def flush
      return if @current.empty?

      @split_segments << (@current.strip.empty? ? @current : Part.new(@current))
      @current = +""
      @current_bytes = 0
    end

    def tags_of(node)
      close_tag = "</#{node.name}>"
      empty = node.document.create_element(node.name)
      node.attribute_nodes.each { |attribute| empty[attribute.name] = attribute.value }

      [empty.to_html.delete_suffix(close_tag), close_tag]
    end
end
