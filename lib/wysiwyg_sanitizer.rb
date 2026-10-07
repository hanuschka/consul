# IMPORTANT: This is the base class extended by AdminWYSIWYGSanitizer.
# When updating the allowed tags or attributes here, also update the JS
# mirror in app/assets/javascripts/studio/utils/htmlUtils.js
# (ProjektStudio.utils.ADMIN_WYSIWYG_ALLOWLIST). Drift between the two
# causes studio content to look different after save than during edit.
class WYSIWYGSanitizer
  EMAIL_ADDRESS_PATTERN = "[^\\s@/:?#]+@[^\\s@/:?#]+\\.[a-z]{2,}".freeze
  EMAIL_ADDRESS = /\A#{EMAIL_ADDRESS_PATTERN}\z/i
  RESOLVED_EMAIL_LINK = %r{\Ahttps?://[^/\s?#]+/(#{EMAIL_ADDRESS_PATTERN})/?\z}i

  def allowed_tags
    %w[ div p ul ol li blockquote br hr a h2 h3 h4 h5 h6 b strong em u s sub sup span img
    table caption thead tr th tbody td abbr
    i
    figure
    iframe
  ]
  end

  def allowed_attributes
    %w[
      href style target class id name alt src align border cellpadding cellspacing summary scope title
      allowfullscreen frameborder height width
      data-src
    ]
  end

  def sanitize(html)
    sanitized = ActionController::Base.helpers.sanitize(html, tags: allowed_tags, attributes: allowed_attributes)

    repair_email_links(sanitized)
  end

  def stripped?(original, sanitized)
    normalize_for_comparison(repair_email_links(original)) != normalize_for_comparison(sanitized)
  end

  def repair_email_links(html)
    return html if html.blank? || html.exclude?("@")

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    repaired = false

    fragment.css("a[href]").each do |anchor|
      address = email_address_from(anchor["href"])
      next if address.nil?

      anchor["href"] = "mailto:#{address}"
      repaired = true
    end

    return html unless repaired

    html.html_safe? ? fragment.to_html.html_safe : fragment.to_html
  end

  private

  def email_address_from(href)
    value = URI::DEFAULT_PARSER.unescape(href.to_s).strip

    return value if value.match?(EMAIL_ADDRESS)

    value[RESOLVED_EMAIL_LINK, 1]
  end

  def normalize_for_comparison(html)
    html.gsub(/<!--.*?-->/m, "").gsub(/\s+/, "")
  end
end
