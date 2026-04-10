class Adm::Projekts::ManagersController < Adm::Projekts::BaseController
  include Admin::PendingRoleAssignable

  def index
    authorize ProjektManager, policy_class: Adm::Projekts::ProjektManagerPolicy

    @pagy, @projekt_managers = pagy(
      policy_scope(ProjektManager, policy_scope_class: Adm::Projekts::ProjektManagerPolicy::Scope)
        .order(id: :desc)
    )

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.projekts"), url: adm_projekts_root_path },
      { name: t("adm.projekts.menu.items.managers"), icon: "badge" }
    ]
  end

  def new
    authorize ProjektManager, policy_class: Adm::Projekts::ProjektManagerPolicy

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.projekts"), url: adm_projekts_root_path },
      { name: t("adm.projekts.menu.items.managers"), url: adm_projekts_managers_path, icon: "badge" },
      { name: t(".title") }
    ]
  end

  def destroy
    @projekt_manager = ProjektManager.find(params[:id])
    authorize @projekt_manager, policy_class: Adm::Projekts::ProjektManagerPolicy

    @projekt_manager.destroy!

    if ProjektManager.none?
      redirect_to adm_projekts_managers_path
    end
  end

  def toggle_manage_all_projekts
    @projekt_manager = ProjektManager.find(params[:id])
    authorize @projekt_manager, :update?, policy_class: Adm::Projekts::ProjektManagerPolicy

    @projekt_manager.update!(manage_all_projekts: !@projekt_manager.manage_all_projekts)
  end

  def search
    authorize ProjektManager, :create?, policy_class: Adm::Projekts::ProjektManagerPolicy

    params[:role] = "projekt_manager"
    @users = User.search(params[:search]).where.missing(:projekt_manager).limit(4)
    check_pending_for_search
  end

  private

    def pending_role_type
      "ProjektManager"
    end
end
