class DeficiencyReportMailer < ApplicationMailer
  helper TextWithLinksHelper

  default from: proc { "#{Setting["mailer_from_name"]} <#{Setting["mailer_from_deficiency_report_address"]}>" }

  def notify_author_about_status_change(deficiency_report)
    @deficiency_report = deficiency_report
    subject = t("custom.deficiency_reports.mailers.notify_author_about_status_change.subject")

    @email_to = @deficiency_report.author.email

    with_user(@deficiency_report.author) do
      mail(to: @email_to, subject: subject)
    end
  end

  def notify_officer(deficiency_report, officer)
    @deficiency_report = deficiency_report
    @deficiency_report_officer = officer
    return if @deficiency_report.blank? || @deficiency_report_officer.blank?


    subject = t("custom.deficiency_reports.mailers.notify_officer.subject",
                identifier: "#{@deficiency_report.id}: #{@deficiency_report.title.first(50)}")
    @email_to = @deficiency_report_officer.email

    with_user(@deficiency_report_officer.user) do
      mail(to: @email_to, subject: subject)
    end
  end

  private

    def with_user(user)
      I18n.with_locale(user.locale) do
        yield
      end
    end
end
