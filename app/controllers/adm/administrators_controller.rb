module Adm
  class AdministratorsController < Adm::BaseController
    include Admin::PendingRoleAssignable

    def index
      authorize [:adm, Administrator]
      @pagy, @administrators = pagy(policy_scope([:adm, Administrator]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.menu.items.profiles_subitems.administrators") }
      ]
    end

    def new
      authorize [:adm, Administrator], :index?

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.menu.items.profiles_subitems.administrators"), url: adm_administrators_path },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, Administrator], :index?
      @administrator = Administrator.find(params[:id])
      @administrator.destroy!
    end

    def search
      authorize [:adm, Administrator], :index?
      params[:role] = "administrator"
      @users = User.search(params[:search]).limit(4)
      check_pending_for_search
    end
  end
end
