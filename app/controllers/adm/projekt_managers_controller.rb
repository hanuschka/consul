module Adm
  class ProjektManagersController < Adm::BaseController
    def index
      authorize [:adm, ProjektManager]
      @pagy, @projekt_managers = pagy(policy_scope([:adm, ProjektManager]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.projekt_managers") }
      ]
    end

    def new
      authorize [:adm, ProjektManager], :index?

      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.projekt_managers"), url: adm_projekt_managers_path },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, ProjektManager], :index?
      @projekt_manager = ProjektManager.find(params[:id])
      @projekt_manager.destroy!
    end

    def search
      authorize [:adm, ProjektManager], :index?
      params[:role] = "projekt_manager"
      @users = User.search(params[:search]).where.missing(:projekt_manager).limit(4)
    end
  end
end
