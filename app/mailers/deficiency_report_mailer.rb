class DeficiencyReportMailer < ApplicationMailer
  include CustomizableEmail
  helper TextWithLinksHelper
  helper :mailer

  default from: proc { "#{Setting["mailer_from_name"]} <#{Setting["mailer_from_deficiency_report_address"]}>" }

  def notify_author_about_status_change(deficiency_report)
    @deficiency_report = deficiency_report
    @email_to = @deficiency_report.author.email

    with_user(@deficiency_report.author) do
      mail_with_custom_template(nil, {
        "username" => @deficiency_report.author.username,
        "deficiency_report_title" => @deficiency_report.title,
        "deficiency_report_url" => deficiency_report_url(@deficiency_report),
        "status_name" => @deficiency_report.status&.name,
        "status_notice_text" => @deficiency_report.status&.notice_text
      }, to: @email_to,
        default_subject: t("custom.deficiency_reports.mailers.notify_author_about_status_change.subject"))
    end
  end

  def notify_officer(deficiency_report, officer)
    @deficiency_report = deficiency_report
    @deficiency_report_officer = officer
    return if @deficiency_report.blank? || @deficiency_report_officer.blank?

    @email_to = @deficiency_report_officer.email

    with_user(@deficiency_report_officer.user) do
      mail_with_custom_template(nil, officer_notification_variables,
        to: @email_to, default_subject: officer_notification_subject)
    end
  end

  def notify_default_officer_group_email(deficiency_report)
    @deficiency_report = deficiency_report
    @email_to = deficiency_report.responsible.default_email

    return if @email_to.blank?

    I18n.with_locale(:de) do
      mail_with_custom_template(nil, officer_notification_variables,
        to: @email_to, default_subject: officer_notification_subject) do |format|
        format.html { render "deficiency_report_mailer/notify_officer" }
      end
    end
  end

  def notify_author_about_submission(deficiency_report)
    @deficiency_report = deficiency_report
    @email_to = @deficiency_report.author.email

    with_user(@deficiency_report.author) do
      mail_with_custom_template(nil, {
        "username" => @deficiency_report.author.username,
        "deficiency_report_title" => @deficiency_report.title,
        "deficiency_report_url" => deficiency_report_url(@deficiency_report),
        "account_url" => account_url
      }, to: @email_to,
        default_subject: t("custom.deficiency_reports.mailers.notify_author_about_submission.subject"))
    end
  end

  # "This Anliegen was shared with you." Carries the opt-out link, so a recipient who does not want
  # the follow-up notifications can drop them without hunting for the bell.
  def notify_shared_report(deficiency_report, user, shared_by)
    @deficiency_report = deficiency_report
    @user = user
    @shared_by = shared_by
    return if @deficiency_report.blank? || @user.blank?

    @email_to = @user.email
    return if @email_to.blank?

    with_user(@user) do
      mail_with_custom_template(nil, watcher_variables.merge("shared_by_name" => @shared_by&.name.to_s),
        to: @email_to,
        default_subject: t("custom.deficiency_reports.mailers.notify_shared_report.subject",
                           identifier: report_identifier))
    end
  end

  # Sent to everyone with the bell on when the Anliegen changes, which is what the bell promises.
  def notify_watcher_about_change(deficiency_report, user)
    @deficiency_report = deficiency_report
    @user = user
    return if @deficiency_report.blank? || @user.blank?

    @email_to = @user.email
    return if @email_to.blank?

    with_user(@user) do
      mail_with_custom_template(nil, watcher_variables,
        to: @email_to,
        default_subject: t("custom.deficiency_reports.mailers.notify_watcher_about_change.subject",
                           identifier: report_identifier))
    end
  end

  def send_feedback_form_link(deficiency_report)
    @deficiency_report = deficiency_report
    @email_to = deficiency_report.author.email

    with_user(@deficiency_report.author) do
      mail_with_custom_template(nil, {
        "username" => @deficiency_report.author.username,
        "deficiency_report_title" => @deficiency_report.title,
        "deficiency_report_url" => deficiency_report_url(@deficiency_report),
        "status_name" => @deficiency_report.status&.name,
        "feedback_form_url" => new_deficiency_report_feedback_form_url(@deficiency_report)
      }, to: @email_to,
        default_subject: t("custom.deficiency_reports.mailers.send_feedback_form_link.subject")) do |format|
        format.html { render "deficiency_report_mailer/send_feedback_form_link" }
      end
    end
  end

  private

    def officer_notification_variables
      {
        "deficiency_report_id" => @deficiency_report.id,
        "deficiency_report_title" => @deficiency_report.title,
        "deficiency_report_url" => adm_deficiency_reports_deficiency_report_url(@deficiency_report),
        "public_deficiency_report_url" =>
          (@deficiency_report.publicly_visible? ? deficiency_report_url(@deficiency_report) : "")
      }
    end

    def officer_notification_subject
      t("custom.deficiency_reports.mailers.notify_officer.subject", identifier: report_identifier)
    end

    def report_identifier
      "#{@deficiency_report.id}: #{@deficiency_report.title.first(50)}"
    end

    def watcher_variables
      officer_notification_variables.merge(
        "username" => @user.username.to_s,
        "unwatch_url" => unwatch_adm_deficiency_reports_deficiency_report_url(@deficiency_report)
      )
    end

    def with_user(user)
      I18n.with_locale(user.locale) do
        yield
      end
    end
end
