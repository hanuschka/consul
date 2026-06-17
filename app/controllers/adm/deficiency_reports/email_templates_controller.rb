class Adm::DeficiencyReports::EmailTemplatesController < Adm::DeficiencyReports::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  def index
    authorize sample_template, :index?,
      policy_class: Adm::SiteCustomization::EmailTemplatePolicy

    @email_templates = ::SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES.map do |mailer_class, mailer_action|
      ::SiteCustomization::EmailTemplate.find_or_create_by!(
        projekt_phase: nil,
        mailer_class: mailer_class,
        mailer_action: mailer_action,
        locale: I18n.locale
      )
    end

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.home"), path: adm_deficiency_reports_root_path },
      { name: t("adm.deficiency_reports.email_templates.index.title") }
    ]
  end

  private

    def sample_template
      mailer_class, mailer_action = ::SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES.first
      ::SiteCustomization::EmailTemplate.new(mailer_class: mailer_class, mailer_action: mailer_action)
    end
end
