require_dependency Rails.root.join("app", "helpers", "content_blocks_helper").to_s

module ContentBlocksHelper
  # A <p> may only contain phrasing content, so any block-level body (e.g. the
  # {{projekt_map}} map embed div) is auto-ejected by the HTML parser and ends
  # up rendered outside the content block. Detect such bodies and wrap them in a
  # <div> instead, whatever tag was requested.
  BLOCK_LEVEL_BODY_REGEXP =
    /<(p|div|section|article|aside|figure|figcaption|table|ul|ol|blockquote|iframe|hr|pre|h[1-6])[\s>]/i

  def render_custom_block(
    key,
    projekt: nil,
    custom_prefix: nil,
    default_content: nil,
    return_path: nil,
    toolbar_position: nil,
    empty_hint: true,
    tag_name: "p"
  )
    locale = current_user&.locale || I18n.default_locale
    block = SiteCustomization::ContentBlock.custom_block_for(key, locale)
    block_body =
      if content_block_body_blank?(block&.body)
        default_content || ""
      else
        block&.body
      end

    block_body = convert_br_to_paragraphs(block_body)

    if custom_prefix
      block_body = "#{custom_prefix} #{block_body}"
    end

    inline_urls = site_content_block_inline_urls(block)

    if inline_urls
      sanitized_body = AdminWYSIWYGSanitizer.new.sanitize(block_body)

      if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? && sanitized_body.include?("</iframe>")
        sanitized_body = process_iframe_embeds(sanitized_body)
      end

      sanitized_default_content = prepare_default_content(default_content)

      res = build_inline_editable_block(
        key,
        block,
        sanitized_body,
        inline_urls,
        default_content: sanitized_default_content,
        toolbar_position: toolbar_position,
        empty_hint: empty_hint,
        tag_name: tag_name
      ).html_safe
    else
      res = build_standard_block(key, block, block_body, projekt, return_path, tag_name: tag_name)

      if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? && res.include?("</iframe>")
        res = process_iframe_embeds(res)
      end

      res = AdminWYSIWYGSanitizer.new.sanitize(res)

      if res.include?("{{projekt_map}}")
        res = process_shortcodes(res, projekt: projekt).html_safe
      end
    end

    res
  end

  def site_content_block_inline_urls(block)
    return nil if block.blank?

    if current_user&.administrator?
      {
        update_url: update_inline_admin_site_customization_content_block_path(block),
        ai_url: change_with_ai_admin_site_customization_content_block_path(block)
      }
    elsif current_user&.projekt_manager?
      {
        update_url: update_inline_projekt_management_site_customization_content_block_path(block),
        ai_url: change_with_ai_projekt_management_site_customization_content_block_path(block)
      }
    end
  end

  def build_inline_editable_block(key, block, block_body, inline_urls, default_content: nil, toolbar_position: nil, empty_hint: true, tag_name: "p")
    block_tag = content_block_tag_name(block_body, tag_name)

    res = "<#{block_tag} id=\"#{key}\" class=\"js-site-content-block custom-content-block-body\" data-turbolinks=\"false\""
    res << " data-content-block-id=\"#{block.id}\""
    res << " data-update-url=\"#{inline_urls[:update_url]}\""
    res << " data-ai-url=\"#{inline_urls[:ai_url]}\""

    if default_content.present?
      res << " data-default-content=\"#{ERB::Util.html_escape(default_content)}\""
    end

    if toolbar_position.present?
      res << " data-toolbar-position=\"#{ERB::Util.html_escape(toolbar_position.to_s)}\""
    end

    persisted_margin = block.attributes_before_type_cast["margin_bottom"]
    if persisted_margin.present?
      res << " style=\"margin-bottom: #{persisted_margin.to_i}px\""
    end

    res << ">#{block_body}</#{block_tag}>"

    if empty_hint && content_block_body_blank?(block_body)
      res = wrap_with_admin_empty_hint(res)
    end

    res
  end

  def wrap_with_admin_empty_hint(block_html)
    wrapper_classes = "content-block-empty-hint-wrap js-toggle-empty-hint-on-content is-content-empty"

    hint = "<div class=\"content-block-empty-hint js-content-block-empty-hint js-studio-hide-on-preview\" role=\"note\">"
    hint << "<span class=\"content-block-empty-hint--icon\" aria-hidden=\"true\"><i class=\"fas fa-circle-info\"></i></span>"
    hint << "<span class=\"content-block-empty-hint--text\">"
    hint << "<strong class=\"content-block-empty-hint--title\">#{ERB::Util.html_escape(I18n.t("custom.content_blocks.admin_empty_hint_title"))}</strong>"
    hint << "<span class=\"content-block-empty-hint--description\">#{ERB::Util.html_escape(I18n.t("custom.content_blocks.admin_empty_hint"))}</span>"
    hint << "</span>"
    hint << "</div>"

    "<div class=\"#{wrapper_classes}\">#{hint}#{block_html}</div>"
  end

  def build_standard_block(key, block, block_body, projekt, return_path, tag_name: "p")
    edit_link = nil

    if current_user&.administrator? && block.present?
      edit_link = link_to(
        '<i class="fas fa-edit"></i>'.html_safe,
        edit_admin_site_customization_content_block_path(block, return_to: return_path || request.path)
      )
    elsif current_user&.projekt_manager? && block.present? && current_user.projekt_manager.allowed_to?(:manage, projekt)
      edit_link = link_to(
        '<i class="fas fa-edit"></i>'.html_safe,
        edit_projekt_management_site_customization_content_block_path(block, return_to: return_path || request.path)
      )
    end

    block_tag = content_block_tag_name(block_body, tag_name)

    res = "<#{block_tag} id=#{key} class=#{'custom-content-block-body' if block_body.present?} data-turbolinks=\"false\">#{block_body}</#{block_tag}>"

    if edit_link
      res << "<div class='custom-content-block-controls js-studio-hide-on-preview'>"
      res << edit_link
      res << "</div>"
    end

    res
  end

  def content_block_tag_name(block_body, tag_name)
    return "div" if tag_name == "p" && block_body.to_s.match?(BLOCK_LEVEL_BODY_REGEXP)

    tag_name
  end

  def render_custom_content_block?(key)
    locale = current_user&.locale || I18n.default_locale
    content_block = SiteCustomization::ContentBlock.find_by(name: "custom", locale: locale, key: key)

    return true if content_block&.body.present?

    current_user.present? && current_user&.administrator?
  end

  def render_custom_projekt_content_block?(key, projekt)
    locale = current_user&.locale || I18n.default_locale
    content_block = SiteCustomization::ContentBlock.find_by(name: "custom", locale: locale, key: key)

    return true if content_block&.body.present?

    current_user&.administrator? || current_user&.projekt_manager?(projekt)
  end

  def current_user_can_edit_content_block?
    (
      current_user &&
      (
        current_user.administrator? ||
        current_user&.projekt_manager?(@custom_page&.projekt)
      )
    )
  end

  def render_projekt_content_block(block)
    block_body = convert_br_to_paragraphs(block&.body)
    key = block.key

    if current_user&.administrator?
      edit_link = link_to('<i class="fas fa-edit"></i>'.html_safe, edit_admin_site_customization_content_block_path(block, return_to: request.path) )
    elsif @custom_page&.projekt && current_user&.projekt_manager?(@custom_page&.projekt)
      edit_link = link_to('<i class="fas fa-edit"></i>'.html_safe, edit_projekt_management_site_customization_content_block_path(block, return_to: request.path) )
    end

    res = "<div id=#{key} class=#{ 'custom-content-block-body' if block_body.present? } data-turbolinks=\"false\">#{block_body}</div>"

    if edit_link
      res << "<div class='custom-content-block-controls js-studio-hide-on-preview'>"
      res << edit_link
      res << "</div>"
    end

    AdminWYSIWYGSanitizer.new.sanitize(res)
  end

  def prepare_default_content(default_content)
    return nil if default_content.blank?

    AdminWYSIWYGSanitizer.new.sanitize(default_content)
  end

  def content_block_body_blank?(body)
    return true if body.blank?

    without_empty_tags = body.gsub(/<br\s*\/?>/, "")
    without_empty_tags = without_empty_tags.gsub(/<\/?(p|div|span)(\s[^>]*)?>/, "")
    without_empty_tags = without_empty_tags.gsub(/[\s\u00A0]/, "")
    without_empty_tags.blank?
  end

  def convert_br_to_paragraphs(html)
    return html if html.blank?

    if html.match?(/<br\s*\/?>/) && !html.match?(BLOCK_LEVEL_BODY_REGEXP)
      html = "<p>#{html}</p>"
    end

    result = html.gsub(/<br\s*\/?>/, "</p><p>")
    result = result.gsub(/<p>\s*<\/p>/, "")
    result
  end

  def safe_content_block_body(body)
    return "" if body.blank?

    AdminWYSIWYGSanitizer.new.sanitize(body)
  end
end
