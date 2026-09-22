class MunicipalPlanMailer < ApplicationMailer
  helper :mailer

  def submitted_for_release(municipal_plan, administrator)
    @municipal_plan = municipal_plan
    @responsible_name = municipal_plan.responsible&.name
    @review_url = adm_municipal_plans_municipal_plan_url(municipal_plan)
    email_to = administrator.email

    return if email_to.blank?

    I18n.with_locale(I18n.default_locale) do
      mail(to: email_to,
           subject: t("custom.municipal_plan_mailer.submitted_for_release.subject",
                      title: municipal_plan.title))
    end
  end
end
