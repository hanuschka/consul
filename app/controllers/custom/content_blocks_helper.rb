require_dependency Rails.root.join("app", "helpers", "content_blocks_helper").to_s

module ContentBlocksHelper
  def render_custom_block(key, projekt: nil, custom_prefix: nil, default_content: nil, return_path: nil)
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

      res = build_inline_editable_block(key, block, sanitized_body, inline_urls, default_content: sanitized_default_content).html_safe
    else
      res = build_standard_block(key, block, block_body, projekt, return_path)

      if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? && res.include?("</iframe>")
        res = process_iframe_embeds(res)
      end

      res = AdminWYSIWYGSanitizer.new.sanitize(res)
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

  def build_inline_editable_block(key, block, block_body, inline_urls, default_content: nil)
    res = "<div id=\"#{key}\" class=\"js-site-content-block custom-content-block-body\""
    res << " data-content-block-id=\"#{block.id}\""
    res << " data-update-url=\"#{inline_urls[:update_url]}\""
    res << " data-ai-url=\"#{inline_urls[:ai_url]}\""

    if default_content.present?
      res << " data-default-content=\"#{ERB::Util.html_escape(default_content)}\""
    end

    res << ">#{block_body}</div>"

    res
  end

  def build_standard_block(key, block, block_body, projekt, return_path)
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

    res = "<div id=#{key} class=#{'custom-content-block-body' if block_body.present?}>#{block_body}</div>"

    if edit_link
      res << "<div class='custom-content-block-controls js-studio-hide-on-preview'>"
      res << edit_link
      res << "</div>"
    end

    res
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

    res = "<div id=#{key} class=#{ 'custom-content-block-body' if block_body.present? }>#{block_body}</div>"

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

    result = html.gsub(/<br\s*\/?>/, "</p><p>")
    result = result.gsub(/<p>\s*<\/p>/, "")
    result
  end
end
