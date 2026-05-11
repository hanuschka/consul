class Adm::LandingPages::BaseController < Adm::BaseController
  before_action :verify_landing_page_manager

  rescue_from Pundit::NotAuthorizedError do |exception|
    Sentry.capture_exception(exception, level: :warning)
    redirect_to adm_landing_pages_root_path, alert: t("adm.not_authorized")
  end

  private

    def adm_menu_component
      Adm::LandingPages::MenuComponent.new
    end

    def adm_header_title
      I18n.t("adm.landing_pages.title")
    end

    def verify_landing_page_manager
      raise Pundit::NotAuthorizedError unless current_user&.landing_page_manager? || current_user&.administrator?
    end
end
