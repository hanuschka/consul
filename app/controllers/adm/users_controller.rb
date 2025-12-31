module Adm
  class UsersController < Adm::BaseController
    def index
      authorize [:adm, User]
      scope = policy_scope([:adm, User])

      if params[:sort_by] && params[:sort_direction]
        scope = scope.order("#{params[:sort_by]} #{params[:sort_direction]}")
      end

      @pagy, @users = pagy(scope)

      @username_header_options = {
        sort: true,
        filter_options: @users.pluck(:id, :username).to_h
      }

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.users") }
      ]
    end
  end
end
