class Adm::MunicipalPlans::BaseController < Adm::BaseController
  before_action :verify_municipal_plans_access

  rescue_from Pundit::NotAuthorizedError do |exception|
    handle_not_authorized(exception, adm_root_path)
  end

  private

    def verify_municipal_plans_access
      raise Pundit::NotAuthorizedError unless current_user&.administrator? ||
                                              current_user&.municipal_plan_officer?
    end
end
