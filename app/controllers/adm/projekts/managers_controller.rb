class Adm::Projekts::ManagersController < Adm::Projekts::BaseController
  def index
    @pagy, @projekt_managers = pagy(
      policy_scope(ProjektManager, policy_scope_class: Adm::Projekts::ProjektManagerPolicy::Scope)
        .order(id: :desc)
    )

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.projekts"), url: adm_projekts_root_path },
      { name: t("adm.projekts.menu.items.managers") }
    ]
  end

  def new
    authorize ProjektManager, :index?, policy_class: Adm::Projekts::ProjektManagerPolicy

    @breadcrumbs = [
      { name: t("adm.projekts.menu.items.projekts"), url: adm_projekts_root_path },
      { name: t("adm.projekts.menu.items.managers"), url: adm_projekts_managers_path },
      { name: t(".title") }
    ]
  end

  def destroy
    @projekt_manager = ProjektManager.find(params[:id])
    authorize @projekt_manager, policy_class: Adm::Projekts::ProjektManagerPolicy

    @projekt_manager.destroy!
  end

  def search
    authorize ProjektManager, :index?, policy_class: Adm::Projekts::ProjektManagerPolicy
    params[:role] = "projekt_manager"
    @users = User.search(params[:search]).where.missing(:projekt_manager).limit(4)
  end
end
