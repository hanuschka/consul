# What stored HTML says about files that do not travel.
#
# An export carries no binary, so any address in it that points into this
# instance's storage points at a file the target does not have -- and a signed
# blob id does not even verify over there. Pictures become placeholders, because
# a visible stand-in tells the admin what to replace. Everything else loses its
# address instead: an inert link or frame is honest, a broken one is not.
#
# What is NOT touched: an address that is not ours. A YouTube or Vimeo embed in
# a content block works the same on any instance, and replacing it would break
# something that was never local in the first place.
class Projekts::Exporting::StoredFileRewriter
  # The host the AI import already writes its image slots against, so an
  # imported projekt shows the same kind of stand-in an AI-generated one does.
  PLACEHOLDER_HOST = "https://placehold.co".freeze

  DEFAULT_WIDTH = 1200
  DEFAULT_HEIGHT = 500

  # Only the dimensions a browser would honour without a stylesheet: an
  # attribute, or a length in the element's own inline style.
  INLINE_LENGTH_FORMAT = '(?:\A|;)\s*%s\s*:\s*(\d+(?:\.\d+)?)px'.freeze

  # Elements that render as a picture, so a placeholder image reads as one.
  # A `source` only counts when it is not feeding a video or audio player.
  PICTURE_SELECTOR = "img, source".freeze
  PLAYER_PARENTS = %w[video audio].freeze

  # A poster frame is an image whatever carries it, so it becomes a placeholder
  # even on a player whose own address is left alone.
  POSTER_SELECTOR = "[poster]".freeze

  # Elements that play or embed a file. A placeholder image in one of these
  # renders as nothing, so a local address is removed and a remote one kept.
  EMBED_SELECTOR = "video, audio, iframe, embed, object".freeze

  LINK_SELECTOR = "a[href]".freeze
  BACKGROUND_SELECTOR = "[style*='url(']".freeze
  BACKGROUND_URL = /url\(\s*(['"]?)([^)'"]*)\1\s*\)/i

  # Where this app serves stored files from.
  STORED_FILE_PATH = %r{/(?:rails/active_storage|rails/representations|uploads|system)/}

  # Attributes that can carry an address. `srcset` and `sizes` are dropped
  # rather than rewritten: a placeholder has one resolution, so a responsive
  # set would keep pointing at the source instance for every viewport but one.
  PICTURE_ATTRIBUTES = %w[src data-src data-original data-large-src].freeze
  EMBED_ATTRIBUTES = %w[src data].freeze
  DROPPED_ATTRIBUTES = %w[srcset data-srcset sizes].freeze

  def self.call(html)
    new(html).call
  end

  def initialize(html)
    @html = html
  end

  def call
    return html if html.blank?
    return html if !rewritable?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css(PICTURE_SELECTOR).each { |element| rewrite_picture(element) }
    fragment.css(POSTER_SELECTOR).each { |element| rewrite_poster(element) }
    fragment.css(EMBED_SELECTOR).each { |element| strip_stored_embed(element) }
    fragment.css(LINK_SELECTOR).each { |element| strip_stored_link(element) }
    fragment.css(BACKGROUND_SELECTOR).each { |element| rewrite_background(element) }

    fragment.to_html
  end

  private

    attr_reader :html

    def rewritable?
      html.match?(/<(img|source|video|audio|embed|iframe|object|a)\b/i) ||
        html.include?("url(")
    end

    # Every picture address is replaced, not only the ones that look local: a
    # remote image the source instance chose is still that instance's choice,
    # and the admin who sees a placeholder knows to make their own.
    def rewrite_picture(element)
      return if player_source?(element)

      placeholder = placeholder_url(element)

      PICTURE_ATTRIBUTES.each do |attribute|
        next if element[attribute].blank?

        element[attribute] = placeholder
      end

      DROPPED_ATTRIBUTES.each { |attribute| element.remove_attribute(attribute) }
    end

    def rewrite_poster(element)
      element["poster"] = placeholder_url(element)
    end

    def player_source?(element)
      element.name == "source" && PLAYER_PARENTS.include?(element.parent&.name)
    end

    # A player's own `source` children are stripped here rather than by
    # rewrite_picture, which skips them for exactly this reason.
    def strip_stored_embed(element)
      (element.css("source").to_a + [element]).each do |target|
        EMBED_ATTRIBUTES.each do |attribute|
          next if !target[attribute].to_s.match?(STORED_FILE_PATH)

          target.remove_attribute(attribute)
        end

        DROPPED_ATTRIBUTES.each { |attribute| target.remove_attribute(attribute) }
      end
    end

    def strip_stored_link(element)
      return if !element["href"].to_s.match?(STORED_FILE_PATH)

      element.remove_attribute("href")
      element.remove_attribute("target")
    end

    def rewrite_background(element)
      style = element["style"]
      return if style.blank?

      element["style"] = style.gsub(BACKGROUND_URL) do
        "url('#{placeholder_url(element)}')"
      end
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
