class Adm::BaseController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  default_form_builder KernFormBuilder

  layout "adm"

  before_action :authenticate_user!
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError do |exception|
    Sentry.capture_exception(exception, level: :warning)
    redirect_to adm_root_path, alert: t("adm.not_authorized")
  end

  helper KernHelper
  helper_method :adm_menu_component, :adm_header_title

  private

    def frame_partial_path
      turbo_frame_request_id&.gsub("__", "/")
    end

    def adm_menu_component
      Adm::MenuComponent.new
    end

    def adm_header_title
      I18n.t("adm.title")
    end

    def policy_class_for(record)
      record_class = record.is_a?(Class) ? record : record.class.base_class

      case record_class.name
      when "Setting"
        Adm::SettingPolicy
      when "Projekt"
        Adm::Projekts::ProjektPolicy
      when "ProjektSetting"
        Adm::Projekts::ProjektSettingPolicy
      when "ProjektPhase", "ProjektPhaseSetting"
        Adm::Projekts::ProjektPhasePolicy
      when "ProjektManager"
        Adm::Projekts::ProjektManagerPolicy
      when "Idea"
        Adm::Ideas::IdeaPolicy
      when "DeficiencyReport"
        Adm::DeficiencyReports::DeficiencyReportPolicy
      when "Poll::Question"
        Adm::Projekts::PollQuestionPolicy
      when "Budget::Phase", "Budget", "Budget::Investment", "Budget::Heading"
        Adm::Projekts::BudgetPolicy
      when "ExternalApiKey"
        Adm::ExternalApiKeyPolicy
      when "ApiClient"
        Adm::ApiClientPolicy
      when "ApiRequestLog"
        Adm::ApiRequestLogPolicy
      when "SiteCustomization::EmailTemplate"
        Adm::SiteCustomization::EmailTemplatePolicy
      when "SiteCustomization::Page"
        Adm::SiteCustomization::PagePolicy
      when "SiteCustomization::Image"
        Adm::SiteCustomization::ImagePolicy
      when "SiteCustomization::ContentBlock"
        Adm::SiteCustomization::ContentBlockPolicy
      when "Newsletter"
        Adm::NewsletterPolicy
      when "Image"
        Adm::ImagePolicy
      when "Poll"
        Adm::Projekts::PollPolicy
      else
        raise ArgumentError, "No policy class defined for #{record_class.name}"
      end
    end
end
