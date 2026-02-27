class ModerationMailer < ApplicationMailer
  helper :mailer

  def flag_report(flag)
    @flag = flag
    @flaggable = flag.flaggable
    @reporter = flag.user
    @resource_title = @flaggable.respond_to?(:title) ? @flaggable.title : ""
    @resource_url = resource_url_for(@flaggable)
    @reported_at = @flag.created_at

    subject = I18n.t("custom.moderation_mailer.flag_report.subject")
    email_to = Setting["moderation.reports_notification_email"]

    I18n.with_locale(I18n.default_locale) do
      mail(to: email_to, subject:)
    end
  end

  private

    def resource_url_for(resource)
      return nil if resource.nil?
      return proposal_url(resource) if resource.is_a?(Proposal)

      nil
    end
end
