class Adm::LandingPages::BaseController < Adm::BaseController
  before_action :verify_landing_page_manager

  rescue_from Pundit::NotAuthorizedError do |exception|
    handle_not_authorized(exception, adm_landing_pages_root_path)
  end

  private

    def verify_landing_page_manager
      raise Pundit::NotAuthorizedError unless current_user&.landing_page_manager? || current_user&.administrator?
    end
end
