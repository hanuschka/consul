class AccessibilityReportMailer < ApplicationMailer
  helper :mailer

  BCC_ADDRESS = "info@demokratie.today".freeze

  def report_submitted(report_attributes)
    @report = AccessibilityReport.new(report_attributes)
    email_to = Setting["accessibility_report.recipient_email"].presence ||
               User.joins(:administrator).pluck(:email).compact_blank

    return if email_to.blank?

    I18n.with_locale(I18n.default_locale) do
      mail(to: email_to,
           bcc: [Rails.application.secrets.bcc_email, BCC_ADDRESS].compact_blank,
           reply_to: @report.email.presence,
           subject: t("accessibility_report_mailer.report_submitted.subject"))
    end
  end

  def confirmation(email_to, locale)
    return if email_to.blank?

    I18n.with_locale(locale) do
      mail(to: email_to, subject: t("accessibility_report_mailer.confirmation.subject"))
    end
  end
end
