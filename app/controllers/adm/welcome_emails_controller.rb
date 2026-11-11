class Adm::WelcomeEmailsController < Adm::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  def index
    authorize ::SiteCustomization::EmailTemplate, policy_class: Adm::SiteCustomization::EmailTemplatePolicy

    @email_template = ::SiteCustomization::EmailTemplate.find_or_create_by!(
      projekt_phase: nil, mailer_class: "Mailer", mailer_action: "welcome", locale: I18n.default_locale
    )

    @breadcrumbs = [
      { name: t("adm.menu.items.notifications"), icon: "send" },
      { name: t("adm.welcome_emails.index.title") }
    ]
  end
end
