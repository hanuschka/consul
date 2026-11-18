class ExternalContentSanitizer < WYSIWYGSanitizer
  EXTERNAL_CONTENT_TAG = /<(iframe|img)\b/i

  def allowed_tags
    super - %w[iframe]
  end

  def sanitize(html)
    remove_external_images(super)
  end

  def sanitize_params(params, keys)
    params.each_pair do |key, value|
      if keys.include?(key.to_s) && value.is_a?(String)
        params[key] = sanitize(value).to_str if value.match?(EXTERNAL_CONTENT_TAG)
      elsif value.respond_to?(:each_pair)
        sanitize_params(value, keys)
      elsif value.is_a?(Array)
        value.each { |item| sanitize_params(item, keys) if item.respond_to?(:each_pair) }
      end
    end
  end

  private

    def remove_external_images(html)
      return html if html.blank? || !html.match?(/<img\b/i)

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css("img").each { |image| image.remove unless local_source?(image["src"]) }

      html.html_safe? ? fragment.to_html.html_safe : fragment.to_html
    end

    def local_source?(src)
      src.to_s.strip.match?(%r{\A/(?![/\\])})
    end
end
