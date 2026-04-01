class Adm::GlobalEmailTemplatesController < Adm::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  def index
    authorize ::SiteCustomization::EmailTemplate, policy_class: Adm::SiteCustomization::EmailTemplatePolicy

    @email_templates = ::SiteCustomization::EmailTemplate::GLOBAL_EMAIL_TEMPLATES.map do |mailer_class, mailer_action|
      ::SiteCustomization::EmailTemplate.find_or_create_by!(
        projekt_phase: nil,
        mailer_class: mailer_class,
        mailer_action: mailer_action,
        locale: I18n.locale
      )
    end

    @breadcrumbs = [
      { name: t("adm.menu.items.notifications"), icon: "send" },
      { name: t("adm.global_email_templates.index.title") }
    ]
  end
end
