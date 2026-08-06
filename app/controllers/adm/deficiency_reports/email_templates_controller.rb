class Adm::DeficiencyReports::EmailTemplatesController < Adm::DeficiencyReports::BaseController
  skip_after_action :verify_policy_scoped, only: [:index, :settings]
  before_action :authorize_email_templates, :load_breadcrumbs

  def index
    @email_template_groups =
      ::SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATE_GROUPS.transform_values do |entries|
        entries.map do |mailer_class, mailer_action|
          ::SiteCustomization::EmailTemplate.find_or_create_by!(
            projekt_phase: nil,
            mailer_class: mailer_class,
            mailer_action: mailer_action,
            locale: I18n.locale
          )
        end
      end
  end

  def settings
    @from_address_setting = Setting.find_by!(key: "mailer_from_deficiency_report_address")
    @footer_block = ::SiteCustomization::ContentBlock.custom_block_for(
      MailerFooterHelper::DEFICIENCY_REPORT_EMAIL_FOOTER_BLOCK
    )
  end

  private

    def authorize_email_templates
      authorize sample_template, :index?,
        policy_class: Adm::SiteCustomization::EmailTemplatePolicy
    end

    def load_breadcrumbs
      @breadcrumbs = [
        { name: t("adm.deficiency_reports.menu.items.home"), path: adm_deficiency_reports_root_path },
        { name: t("adm.deficiency_reports.email_templates.index.title") }
      ]
    end

    def sample_template
      mailer_class, mailer_action = ::SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES.first
      ::SiteCustomization::EmailTemplate.new(mailer_class: mailer_class, mailer_action: mailer_action)
    end
end
