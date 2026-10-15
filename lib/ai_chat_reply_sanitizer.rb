# Markup a model wrote for an admin's screen. Images and frames are the two
# ways such a reply can reach out to another server on its own, so neither
# survives; links stay, but only as http(s) and never same-window.
class AiChatReplySanitizer < WYSIWYGSanitizer
  LINK_RELATION = "noopener noreferrer nofollow".freeze

  def allowed_tags
    %w[p br ul ol li blockquote pre code strong b em h3 h4 h5 h6 a hr table thead tbody tr th td]
  end

  def allowed_attributes
    %w[href target rel]
  end

  def sanitize(html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(super)

    fragment.css("a").each do |link|
      link["target"] = "_blank"
      link["rel"] = LINK_RELATION
    end

    fragment.to_html.html_safe
  end
end
