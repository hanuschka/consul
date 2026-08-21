# What stored HTML says about files that do not travel.
#
# An export carries no binary, so every address in it points at a file only the
# source instance has. Pictures become placeholders, because a visible stand-in
# tells the admin what to replace. Links to a stored file lose their address
# instead: their text says what the file was, and a dead link that still looks
# like a link is worse than one that plainly does nothing.
class Projekts::Exporting::StoredFileRewriter
  # The host the AI import already writes its image slots against, so an
  # imported projekt shows the same kind of stand-in an AI-generated one does.
  PLACEHOLDER_HOST = "https://placehold.co".freeze

  DEFAULT_WIDTH = 1200
  DEFAULT_HEIGHT = 500

  # Only the dimensions a browser would honour without a stylesheet: an
  # attribute, or a length in the element's own inline style.
  INLINE_LENGTH_FORMAT = '(?:\A|;)\s*%s\s*:\s*(\d+(?:\.\d+)?)px'.freeze

  MEDIA_SELECTOR = "img, source, video, audio, embed, iframe, object".freeze
  BACKGROUND_SELECTOR = "[style*='url(']".freeze
  LINK_SELECTOR = "a[href]".freeze
  BACKGROUND_URL = /url\(\s*(['"]?)([^)'"]*)\1\s*\)/i

  # Where this app serves stored files from. A link to one of these is a link
  # to a blob of the source instance -- on the target the signed id does not
  # even verify, so it cannot resolve to anything.
  STORED_FILE_PATH = %r{/(?:rails/active_storage|rails/representations|uploads|system)/}

  # Attributes that can carry an address. `srcset` and `sizes` are dropped
  # rather than rewritten: a placeholder has one resolution, so a responsive
  # set would keep pointing at the source instance for every viewport but one.
  ADDRESS_ATTRIBUTES = %w[src poster data-src data-original data-large-src].freeze
  DROPPED_ATTRIBUTES = %w[srcset data-srcset sizes].freeze

  def self.call(html)
    new(html).call
  end

  def initialize(html)
    @html = html
  end

  # Every media address is replaced, not just the ones that look local: the
  # export travels to another instance where no address of ours resolves, and
  # an admin who sees a placeholder knows to replace it.
  def call
    return html if html.blank?
    return html if !rewritable?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css(MEDIA_SELECTOR).each { |element| rewrite_media(element) }
    fragment.css(BACKGROUND_SELECTOR).each { |element| rewrite_background(element) }
    fragment.css(LINK_SELECTOR).each { |element| rewrite_link(element) }

    fragment.to_html
  end

  private

    attr_reader :html

    def rewritable?
      html.match?(/<(img|source|video|audio|embed|iframe|object|a)\b/i) ||
        html.include?("url(")
    end

    def rewrite_media(element)
      placeholder = placeholder_url(element)

      ADDRESS_ATTRIBUTES.each do |attribute|
        next if element[attribute].blank?

        element[attribute] = placeholder
      end

      DROPPED_ATTRIBUTES.each { |attribute| element.remove_attribute(attribute) }
    end

    def rewrite_background(element)
      style = element["style"]
      return if style.blank?

      element["style"] = style.gsub(BACKGROUND_URL) do
        "url('#{placeholder_url(element)}')"
      end
    end

    def rewrite_link(element)
      return if !element["href"].to_s.match?(STORED_FILE_PATH)

      element.remove_attribute("href")
      element.remove_attribute("target")
    end

    def placeholder_url(element)
      width = dimension(element, "width", DEFAULT_WIDTH)
      height = dimension(element, "height", DEFAULT_HEIGHT)

      "#{PLACEHOLDER_HOST}/#{width}x#{height}"
    end

    def dimension(element, property, fallback)
      from_attribute = element[property].to_s[/\A\d+/]
      return from_attribute.to_i if from_attribute.present?

      from_style = element["style"].to_s[inline_length_pattern(property), 1]
      return from_style.to_f.round if from_style.present?

      fallback
    end

    def inline_length_pattern(property)
      Regexp.new(format(INLINE_LENGTH_FORMAT, property), Regexp::IGNORECASE)
    end
end
