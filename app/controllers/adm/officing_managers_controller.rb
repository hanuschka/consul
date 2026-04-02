module Adm
  class OfficingManagersController < Adm::BaseController
    include Admin::PendingRoleAssignable

    def index
      authorize [:adm, OfficingManager]
      @pagy, @officing_managers = pagy(policy_scope([:adm, OfficingManager]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.menu.items.profiles_subitems.officing_managers") }
      ]
    end

    def new
      authorize [:adm, OfficingManager], :index?

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles"), icon: "3p" },
        { name: t("adm.menu.items.profiles_subitems.officing_managers"), url: adm_officing_managers_path },
        { name: t(".title") }
      ]
    end

    def destroy
      authorize [:adm, OfficingManager], :index?
      @officing_manager = OfficingManager.find(params[:id])
      @officing_manager.destroy!
    end

    def search
      authorize [:adm, OfficingManager], :index?
      params[:role] = "officing_manager"
      @users = User.search(params[:search]).where.missing(:officing_manager).limit(4)
      check_pending_for_search
    end
  end
end
