class Adm::BaseController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend
  include LocaleSwitching
  include GlobalizeFallbacks

  default_form_builder KernFormBuilder

  layout "adm"

  before_action :store_return_location_for_login
  before_action :authenticate_user!
  around_action :switch_locale
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError do |exception|
    Sentry.capture_exception(exception, level: :warning)
    redirect_to root_path, alert: t("adm.not_authorized")
  end

  helper KernHelper
  helper_method :adm_menu_component, :adm_header_title, :current_adm_section_namespace

  # Top-level Adm controllers that thematically belong to a section.
  # These bypass the default `self.class.module_parent_name` lookup.
  SECTION_NAMESPACE_OVERRIDES = {
    "Adm::SiteCustomization::PagesController" => "Adm",
    "Adm::ModeratorsController" => "Adm::Moderation",
    "Adm::ValuatorsController" => "Adm::Valuation",
    "Adm::OfficingManagersController" => "Adm::Officing",
    "Adm::ApiClients::ServiceUsersController" => "Adm"
  }.freeze

  private

    # Adm::BaseController inherits from ActionController::Base, so it doesn't run
    # ApplicationController#set_return_url. Without it, an unauthenticated user
    # following a deep /adm link (e.g. from the officer notification email) is
    # bounced to sign in with no stored location and lands on root afterwards.
    def store_return_location_for_login
      return if user_signed_in?
      return unless request.get? && is_navigational_format?

      store_location_for(:user, SessionUrlTruncator.truncate(request.fullpath))
    end

    def frame_partial_path
      turbo_frame_request_id&.gsub("__", "/")
    end

    # Canonical "which adm section am I in" for nav highlighting + menu/title rendering.
    # Priority:
    #   1. routing default (`params[:adm_section]`) — set by routes nested under a section scope
    #   2. explicit override map for top-level controllers
    #   3. the controller's own Ruby parent namespace
    def current_adm_section_namespace
      return "Adm::#{params[:adm_section].camelize}" if params[:adm_section].present?

      SECTION_NAMESPACE_OVERRIDES[self.class.name] || self.class.module_parent_name || "Adm"
    end

    def adm_menu_component
      "#{current_adm_section_namespace}::MenuComponent".safe_constantize&.new || Adm::MenuComponent.new
    end

    def adm_header_title
      namespace = current_adm_section_namespace
      return I18n.t("adm.title") if namespace == "Adm"

      section_key = namespace.demodulize.underscore
      Setting["#{section_key}.feature_name"].presence ||
        I18n.t("#{namespace.gsub('::', '.').underscore}.title")
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
      when "SiteCustomization::Video"
        Adm::SiteCustomization::VideoPolicy
      when "SiteCustomization::ContentBlock"
        Adm::SiteCustomization::ContentBlockPolicy
      when "Newsletter"
        Adm::NewsletterPolicy
      when "Image"
        Adm::ImagePolicy
      when "Document"
        Adm::DocumentPolicy
      when "AdminAsset"
        Adm::AdminAssetPolicy
      when "AdminImage"
        Adm::AdminImagePolicy
      when "Poll"
        Adm::Projekts::PollPolicy
      else
        raise ArgumentError, "No policy class defined for #{record_class.name}"
      end
    end
end
