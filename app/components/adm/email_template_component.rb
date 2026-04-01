class Adm::EmailTemplateComponent < ApplicationComponent
  delegate :ck_editor_class, to: :helpers

  def initialize(email_template)
    @email_template = email_template
  end

  def label
    I18n.t("#{@email_template.mailer_class.underscore}.#{@email_template.mailer_action}.title")
  end

  def description
    I18n.t("#{@email_template.mailer_class.underscore}.#{@email_template.mailer_action}.description")
  end

  def variables
    @email_template.registered_variables
  end

  def variables_hint
    variables.map { |v| "{{ #{v} }}" }.join("<br>")
  end

  def path
    helpers.adm_email_template_path(@email_template)
  end

  def send_test_path
    helpers.send_test_adm_email_template_path(@email_template)
  end

  def sanitized_body
    AdminWYSIWYGSanitizer.new.sanitize(@email_template.body)
  end
end
