# IMPORTANT: This is the base class extended by AdminWYSIWYGSanitizer.
# When updating the allowed tags or attributes here, also update the JS
# mirror in app/assets/javascripts/projekt_studio/utils/htmlUtils.js
# (ProjektStudio.utils.ADMIN_WYSIWYG_ALLOWLIST). Drift between the two
# causes studio content to look different after save than during edit.
class WYSIWYGSanitizer
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
    ActionController::Base.helpers.sanitize(html, tags: allowed_tags, attributes: allowed_attributes)
  end

  def stripped?(original, sanitized)
    normalize_for_comparison(original) != normalize_for_comparison(sanitized)
  end

  private

  def normalize_for_comparison(html)
    html.gsub(/<!--.*?-->/m, "").gsub(/\s+/, "")
  end
end
