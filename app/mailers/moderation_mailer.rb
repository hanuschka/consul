class ModerationMailer < ApplicationMailer
  def flag_report(flag)
    @flag = flag
    @flaggable = flag.flaggable
    @reporter = flag.user
    @resource_type = @flaggable.class.model_name.human
    @resource_snippet = resource_snippet(@flaggable)
    @reported_at = @flag.created_at

    subject = I18n.t(
      "custom.moderation_mailer.flag_report.subject",
      resource_type: @resource_type
    )
    email_to = Setting["moderation.reports_notification_email"]

    I18n.with_locale(I18n.default_locale) do
      mail(to: email_to, subject:)
    end
  end

  private

    def resource_snippet(resource)
      return "" if resource.nil?

      snippet = resource.respond_to?(:title) ? resource.title : nil
      snippet.presence || resource.respond_to?(:body) ? resource.body.to_s.truncate(200) : ""
    end
end
