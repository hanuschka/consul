class Adm::BaseController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  default_form_builder KernFormBuilder

  layout "adm"

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  helper_method :adm_menu_component

  private

    def adm_menu_component
      Adm::MenuComponent.new
    end
end
