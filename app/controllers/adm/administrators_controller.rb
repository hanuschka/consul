module Adm
  class AdministratorsController < Adm::BaseController
    def index
      authorize [:adm, Administrator]
      @pagy, @administrators = pagy(policy_scope([:adm, Administrator]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.administrators") }
      ]
    end

    def create
      authorize [:adm, Administrator], :index?
      @administrator = Administrator.find_or_create_by!(user_id: params[:user_id])
    end

    def destroy
      authorize [:adm, Administrator], :index?
      @administrator = Administrator.find(params[:id])
      @administrator.destroy!
    end

    def search
      authorize [:adm, Administrator], :index?
      @users = User.search(params[:search]).includes(:administrator).limit(4)
    end
  end
end
