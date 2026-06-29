module MailerFooterHelper
  SYSTEM_EMAIL_FOOTER_BLOCK = "email_footer".freeze
  DEFICIENCY_REPORT_EMAIL_FOOTER_BLOCK = "email_footer_deficiency_report".freeze

  FOOTERLESS_MAILER_CLASSES = %w[DeviseMailer].freeze
  FOOTERLESS_EMAILS = [
    ["Mailer", "newsletter"]
  ].freeze

  def customizable_email_footer_html
    return if custom_email_footer_excluded?

    body = email_footer_block_body(customizable_email_footer_block_key)
    return if body.blank?

    tighten_block_margins(AdminWYSIWYGSanitizer.new.sanitize(body))
  end

  def append_custom_email_footer(body_html)
    footer = customizable_email_footer_html
    return body_html if footer.blank?

    wrapper = content_tag(
      :div, footer,
      style: "font-family: 'Open Sans','Helvetica Neue',arial,sans-serif;font-size: 14px;font-weight: normal;line-height: 24px;text-align: left;"
    )

    index = body_html.rindex("</td>")
    return safe_join([body_html, wrapper]) unless index

    safe_join([body_html[0...index], wrapper, body_html[index..]])
  end

  def custom_email_footer_present?
    return false if custom_email_footer_excluded?

    email_footer_block_body(customizable_email_footer_block_key).present?
  end

  private

    def tighten_block_margins(html)
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      elements = fragment.children.select(&:element?)
      return html if elements.empty?

      prepend_inline_style(elements.first, "margin-top:0;")
      prepend_inline_style(elements.last, "margin-bottom:0;")
      fragment.to_html.html_safe
    end

    def prepend_inline_style(node, style)
      node["style"] = "#{style}#{node["style"]}"
    end

    def customizable_email_footer_block_key
      if deficiency_report_email? && email_footer_block_body(DEFICIENCY_REPORT_EMAIL_FOOTER_BLOCK).present?
        DEFICIENCY_REPORT_EMAIL_FOOTER_BLOCK
      else
        SYSTEM_EMAIL_FOOTER_BLOCK
      end
    end

    def deficiency_report_email?
      SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES.include?(
        [controller.class.name, action_name]
      )
    end

    def custom_email_footer_excluded?
      FOOTERLESS_MAILER_CLASSES.include?(controller.class.name) ||
        FOOTERLESS_EMAILS.include?([controller.class.name, action_name])
    end

    def email_footer_block_body(key)
      SiteCustomization::ContentBlock.find_by(
        name: "custom",
        key: key,
        locale: I18n.default_locale
      )&.body
    end
end
