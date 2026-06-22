module CustomizableEmail
  extend ActiveSupport::Concern

  private

    def find_custom_template(projekt_phase)
      SiteCustomization::EmailTemplate.find_template(
        projekt_phase,
        self.class.name,
        action_name,
        I18n.locale
      )
    end

    # The optional block is forwarded to the default-template branch so callers
    # that render a non-conventional view (format.html { render "..." }) keep
    # working when no override is configured.
    def mail_with_custom_template(projekt_phase, variables, to:, default_subject:, &block)
      template = find_custom_template(projekt_phase)

      if template&.customized?
        @custom_email_subject = template.render_subject(variables) || default_subject
        @custom_email_body = template.render_body(variables)
        mail(to: to, subject: @custom_email_subject, template_path: "mailer", template_name: "customizable_email")
      else
        mail(to: to, subject: default_subject, &block)
      end
    end
end
