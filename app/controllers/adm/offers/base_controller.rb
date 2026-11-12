class Adm::Offers::BaseController < Adm::BaseController
  before_action :verify_offers_access

  rescue_from Pundit::NotAuthorizedError do |exception|
    handle_not_authorized(exception, adm_root_path)
  end

  private

    def verify_offers_access
      raise Pundit::NotAuthorizedError unless Adm::Offers::OfferPolicy.new(current_user, nil).index?
    end
end
