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

    def mail_with_custom_template(projekt_phase, variables, to:, default_subject:)
      template = find_custom_template(projekt_phase)

      if template&.customized?
        @custom_email_subject = template.render_subject(variables) || default_subject
        @custom_email_body = template.render_body(variables)
        mail(to: to, subject: @custom_email_subject, template_path: "mailer", template_name: "customizable_email")
      else
        mail(to: to, subject: default_subject)
      end
    end
end
