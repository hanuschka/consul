module Adm
  class OfficingManagersController < Adm::Officing::BaseController
    include Admin::PendingRoleAssignable
    skip_before_action :set_officing_manager

    def index
      authorize [:adm, OfficingManager]
      @pagy, @officing_managers = pagy(policy_scope([:adm, OfficingManager]).order(id: :desc))

      @breadcrumbs = [
        { name: t("adm.officing_managers.index.title"), icon: "badge" }
      ]
    end

    def new
      authorize [:adm, OfficingManager], :index?

      @breadcrumbs = [
        { name: t("adm.officing_managers.index.title"), url: adm_officing_managers_path, icon: "badge" },
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
