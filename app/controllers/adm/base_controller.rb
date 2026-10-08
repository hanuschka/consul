class Adm::BaseController < ActionController::Base
  include Pundit::Authorization
  include Adm::PolicyLookup
  include Pagy::Backend
  include LocaleSwitching

  default_form_builder KernFormBuilder

  layout "adm"

  before_action :store_return_location_for_login
  before_action :authenticate_user!
  around_action :switch_locale
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError do |exception|
    handle_not_authorized(exception, root_path)
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

    def current_locale
      locale = super

      adm_locale?(locale) ? locale : I18n.default_locale
    end

    def explicit_locale_param
      locale = super

      locale if adm_locale?(locale)
    end

    def adm_locale?(locale)
      SupportedLocales.adm?(locale)
    end

    def handle_not_authorized(exception, fallback_path)
      Sentry.capture_exception(exception, level: :warning)

      if turbo_frame_request_id.present?
        render turbo_stream: turbo_stream.replace(
          turbo_frame_request_id,
          not_authorized_frame_message
        ), status: :forbidden
      else
        redirect_to fallback_path, alert: t("adm.not_authorized")
      end
    end

    def not_authorized_frame_message
      request.get? ? t("adm.not_authorized") : t("adm.not_authorized_edit")
    end

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
end
