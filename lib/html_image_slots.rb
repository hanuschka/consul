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

  # GLightbox packs its options into one attribute as "key:value;key:value".
  GLIGHTBOX_HREF = /href:[^;]*/i

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

  # The single "does this element carry a fillable picture" rule, so counting and
  # filling can never disagree about what a template has room for.
  def self.slot?(node, replacements = [])
    return fillable?(node["src"], replacements) if image?(node)

    fillable?(background_url(node), replacements)
  end

  def self.image?(node)
    node.name.casecmp("img").zero?
  end

  def self.background_url(node)
    style = node["style"]
    return nil if style.blank?

    style[URL_IN_STYLE, 2]
  end

  def self.fill_element(node, remaining, replacements)
    return if !slot?(node, replacements)

    url = remaining.shift
    return fill_image(node, url) if image?(node)

    node["style"] = node["style"].sub(URL_IN_STYLE, "url('#{url}')")
  end

  def self.fill_image(node, url)
    node["src"] = url
    node["data-src"] = url if node["data-src"].present?
    node.remove_attribute("srcset")
    fill_lightbox_target(node, url)
  end

  # The gallery templates open the full-size picture in a GLightbox overlay, and
  # the address it opens is not in the <img>. Substituting only the thumbnail
  # leaves the overlay on the template's placeholder, so a visitor clicks a real
  # photo and gets a placehold.co graphic full screen.
  #
  # Two shapes are in the live catalogue and both are handled: an ancestor anchor
  # whose href is the target (image-single, gallery-*), and a sibling overlay
  # button with href="#" carrying the target inside
  # data-glightbox="href:URL;type:image" (hero-slider). The "#" is deliberately
  # left alone in the second shape — GLightbox reads the data attribute, and
  # rewriting a no-op link would break it.
  #
  # It consumes no slot and is not counted as one: it is the same picture as the
  # thumbnail, at whatever size the variant gives us.
  def self.fill_lightbox_target(image_node, url)
    anchor = lightbox_anchor_for(image_node)
    return if anchor.nil?
    return if fill_lightbox_data(anchor, url)

    anchor["href"] = url if fillable?(anchor["href"], [])
  end

  # Keyed on the lightbox markup rather than on "an <a> with a replaceable href":
  # plenty of templates wrap an image in a link that goes somewhere real, and
  # overwriting those with an image URL would break the navigation.
  def self.lightbox_anchor_for(image_node)
    ancestor = image_node.ancestors("a").find { |node| lightbox_anchor?(node) }
    return ancestor if ancestor.present?

    image_node.parent&.css("a")&.find { |node| lightbox_anchor?(node) }
  end

  def self.lightbox_anchor?(node)
    return true if node["data-glightbox"].present?

    node["class"].to_s.split.include?("glightbox")
  end

  def self.fill_lightbox_data(anchor, url)
    options = anchor["data-glightbox"]
    return false if options.blank?
    return false if !options.match?(GLIGHTBOX_HREF)

    anchor["data-glightbox"] = options.sub(GLIGHTBOX_HREF, "href:#{url}")
    true
  end

  private_class_method :fill_element, :fill_image, :background_url, :image?,
                       :fill_lightbox_target, :lightbox_anchor_for, :lightbox_anchor?,
                       :fill_lightbox_data
end
