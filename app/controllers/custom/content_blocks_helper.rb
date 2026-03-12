require_dependency Rails.root.join("app", "helpers", "content_blocks_helper").to_s

module ContentBlocksHelper
  def render_custom_block(key, projekt: nil, custom_prefix: nil, default_content: nil, return_path: nil)
    locale = current_user&.locale || I18n.default_locale
    block = SiteCustomization::ContentBlock.custom_block_for(key, locale)
    block_body = block&.body.presence || default_content || ""

    if custom_prefix
      block_body = "#{custom_prefix} #{block_body}"
    end

    inline_urls = site_content_block_inline_urls(block)

    if block_body.present? && current_user && current_user.email.in?(@partner_emails || [])
      copy_link = link_to(
        '<i class="fas fa-code"></i>'.html_safe,
        '#',
        class: 'js-copy-source-button',
        style: "margin-left:10px",
        data: { target: key }
      )
    end

    if inline_urls
      sanitized_body = AdminWYSIWYGSanitizer.new.sanitize(block_body)

      if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? && sanitized_body.include?("</iframe>")
        sanitized_body = process_iframe_embeds(sanitized_body)
      end

      res = build_inline_editable_block(key, block, sanitized_body, inline_urls, copy_link).html_safe
    else
      res = build_standard_block(key, block, block_body, projekt, return_path, copy_link)

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

  def build_inline_editable_block(key, block, block_body, inline_urls, copy_link)
    res = "<div id=\"#{key}\" class=\"js-site-content-block custom-content-block-body\""
    res << " data-content-block-id=\"#{block.id}\""
    res << " data-update-url=\"#{inline_urls[:update_url]}\""
    res << " data-ai-url=\"#{inline_urls[:ai_url]}\""
    res << ">#{block_body}</div>"

    if copy_link.present?
      res << "<div class='custom-content-block-controls js-projekt-studio-hide-on-preview'>"
      res << copy_link
      res << "</div>"
    end

    res
  end

  def build_standard_block(key, block, block_body, projekt, return_path, copy_link)
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

    if edit_link || copy_link
      res << "<div class='custom-content-block-controls js-projekt-studio-hide-on-preview'>"
      res << edit_link if edit_link.present?
      res << copy_link if copy_link.present?
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
    block_body = block&.body
    key = block.key

    if current_user&.administrator?
      edit_link = link_to('<i class="fas fa-edit"></i>'.html_safe, edit_admin_site_customization_content_block_path(block, return_to: request.path) )
    elsif @custom_page&.projekt && current_user&.projekt_manager?(@custom_page&.projekt)
      edit_link = link_to('<i class="fas fa-edit"></i>'.html_safe, edit_projekt_management_site_customization_content_block_path(block, return_to: request.path) )
    end

    if block_body.present? && current_user && current_user.email.in?(@partner_emails)
      copy_link = link_to '<i class="fas fa-code"></i>'.html_safe, '#', class: 'js-copy-source-button', style: "#{'margin-left:10px' if edit_link.present?}", data: { target: key }
    end

    res = "<div id=#{key} class=#{ 'custom-content-block-body' if block_body.present? }>#{block_body}</div>"

    if edit_link || copy_link
      res << "<div class='custom-content-block-controls js-projekt-studio-hide-on-preview'>"
        res << edit_link if edit_link.present?
        res << copy_link if copy_link.present?
      res << "</div>"
    end

    AdminWYSIWYGSanitizer.new.sanitize(res)
  end
end
