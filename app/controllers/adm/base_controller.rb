class Adm::BaseController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  layout "adm"

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
end
