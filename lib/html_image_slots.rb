# Puts real image URLs into the picture slots of a fragment of HTML, in the order
# the slots appear.
#
# Used where an HTML fragment is produced by a language model: asking a model to
# copy a URL into an <img src> looks simpler, but the ways it goes wrong are all
# silent — the URL comes back shortened, reordered, used twice, or invented. The
# model is therefore only asked to leave a placeholder, and the addresses are
# written in afterwards, here.
#
# A slot is an <img>, and also an element whose inline style paints a
# background-image, because a hero or full-width overlay block carries its
# picture that way and would otherwise be skipped.
module HtmlImageSlots
  URL_IN_STYLE = /url\((['"]?)(.*?)\1\)/i

  # Decoration rather than content: an icon, a data URI, or a picture already
  # pointing at one of the addresses being handed out.
  def self.fillable?(url, replacements)
    return false if url.blank?
    return false if url.start_with?("data:")
    return false if url.downcase.end_with?(".svg")

    replacements.exclude?(url)
  end

  # Returns the rewritten HTML and how many URLs it consumed, so a caller
  # walking several fragments can hand the rest to the next one.
  def self.fill(html, urls)
    return { html: html, used: 0 } if html.blank? || urls.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    remaining = urls.dup

    # css("*") rather than traverse: traverse visits children before parents, so
    # a wrapper painting a background would be filled after the gallery cells
    # inside it instead of in reading order.
    fragment.css("*").each do |node|
      break if remaining.empty?

      fill_element(node, remaining, urls)
    end

    { html: fragment.to_html, used: urls.size - remaining.size }
  end

  # How many pictures this fragment has room for, counted by the same rule fill
  # uses. Anything that counts slots separately — a prompt telling a model which
  # templates can hold an image, for instance — drifts from what actually gets
  # filled: counting only <img> misses the hero and full-width overlay templates
  # that carry their picture as a background-image.
  def self.count(html)
    return 0 if html.blank?

    Nokogiri::HTML::DocumentFragment
      .parse(html)
      .css("*")
      .count { |node| slot?(node) }
  end

  def self.slot?(node)
    return fillable?(node["src"], []) if node.name.casecmp("img").zero?

    style = node["style"]
    return false if style.blank?
    return false if !style.match?(URL_IN_STYLE)

    fillable?(style[URL_IN_STYLE, 2], [])
  end

  def self.fill_element(node, remaining, replacements)
    if node.name.casecmp("img").zero?
      return fill_image(node, remaining, replacements)
    end

    fill_background(node, remaining, replacements)
  end

  def self.fill_image(node, remaining, replacements)
    return if !fillable?(node["src"], replacements)

    url = remaining.shift
    node["src"] = url
    node["data-src"] = url if node["data-src"].present?
    node.remove_attribute("srcset")
  end

  def self.fill_background(node, remaining, replacements)
    style = node["style"]
    return if style.blank?
    return if !style.match?(URL_IN_STYLE)
    return if !fillable?(style[URL_IN_STYLE, 2], replacements)

    url = remaining.shift
    node["style"] = style.sub(URL_IN_STYLE, "url('#{url}')")
  end

  private_class_method :fill_element, :fill_image, :fill_background
end
